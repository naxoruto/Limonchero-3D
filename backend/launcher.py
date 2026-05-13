"""
Limonchero 3D — Bootstrapper
Ensures Ollama + models + Whisper are available, then starts the backend.
"""

import os
import sys
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path
from typing import Optional


def _is_windows() -> bool:
    return os.name == "nt"


def _base_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


BASE_DIR = _base_dir()
OLLAMA_INSTALLER_URL = os.environ.get(
    "OLLAMA_INSTALLER_URL",
    "https://ollama.com/download/OllamaSetup.exe",
)
NVIDIA_WINGET_ID = os.environ.get("NVIDIA_WINGET_ID", "NVIDIA.GeForceExperience")
AUTO_INSTALL_NVIDIA_DRIVER = os.environ.get("AUTO_INSTALL_NVIDIA_DRIVER", "1")


def _log(message: str) -> None:
    print(message, flush=True)


def _command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def _find_ollama_cmd() -> Optional[str]:
    if _command_exists("ollama"):
        return "ollama"

    if _is_windows():
        local_app = os.environ.get("LOCALAPPDATA")
        if local_app:
            candidate = Path(local_app) / "Programs" / "Ollama" / "ollama.exe"
            if candidate.exists():
                return str(candidate)

    return None


def _is_admin() -> bool:
    if not _is_windows():
        return True

    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def _download_file(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return

    dest.parent.mkdir(parents=True, exist_ok=True)
    _log(f"Downloading: {url}")
    with urllib.request.urlopen(url) as response, open(dest, "wb") as handle:
        shutil.copyfileobj(response, handle)


def _run_installer(installer_path: Path) -> None:
    if not _is_windows():
        return

    if _is_admin():
        subprocess.run([str(installer_path), "/SILENT"], check=True)
        return

    quoted = str(installer_path).replace("'", "''")
    subprocess.run(
        [
            "powershell",
            "-Command",
            f"Start-Process -FilePath '{quoted}' -ArgumentList '/SILENT' -Verb RunAs -Wait",
        ],
        check=True,
    )


def _ensure_ollama_installed() -> str:
    ollama_cmd = _find_ollama_cmd()
    if ollama_cmd:
        return ollama_cmd

    if not _is_windows():
        raise RuntimeError("Ollama not found. Install it manually for this OS.")

    installer_path = BASE_DIR / "OllamaSetup.exe"
    _download_file(OLLAMA_INSTALLER_URL, installer_path)
    _log("Running Ollama installer...")
    _run_installer(installer_path)

    ollama_cmd = _find_ollama_cmd()
    if not ollama_cmd:
        raise RuntimeError("Ollama install finished, but CLI was not found.")

    return ollama_cmd


def _ollama_list(ollama_cmd: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [ollama_cmd, "list"],
        capture_output=True,
        text=True,
    )


def _ensure_ollama_ready(ollama_cmd: str) -> str:
    result = _ollama_list(ollama_cmd)
    if result.returncode == 0:
        return result.stdout

    _log("Ollama not responding, starting server...")
    subprocess.Popen(
        [ollama_cmd, "serve"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    for _ in range(10):
        time.sleep(1)
        result = _ollama_list(ollama_cmd)
        if result.returncode == 0:
            return result.stdout

    raise RuntimeError(f"Ollama did not respond: {result.stderr.strip()}")


def _ensure_ollama_model(ollama_cmd: str, model_name: str) -> None:
    output = _ensure_ollama_ready(ollama_cmd)
    if model_name in output:
        _log(f"Ollama model '{model_name}' already present.")
        return

    _log(f"Pulling Ollama model '{model_name}'...")
    subprocess.run([ollama_cmd, "pull", model_name], check=True)


def _has_nvidia_gpu_windows() -> bool:
    if not _is_windows():
        return False

    result = subprocess.run(
        [
            "powershell",
            "-Command",
            "(Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name)",
        ],
        capture_output=True,
        text=True,
    )
    return "NVIDIA" in result.stdout.upper()


def _try_install_nvidia_driver() -> bool:
    if not _is_windows():
        return False

    if AUTO_INSTALL_NVIDIA_DRIVER.lower() in {"0", "false", "no"}:
        return False

    if not _command_exists("winget"):
        return False

    _log("Attempting NVIDIA driver install via winget...")
    result = subprocess.run(
        [
            "winget",
            "install",
            "-e",
            "--id",
            NVIDIA_WINGET_ID,
            "--accept-package-agreements",
            "--accept-source-agreements",
        ],
        check=False,
    )
    return result.returncode == 0


def _ensure_whisper_model(config) -> None:
    model_path = Path(config.WHISPER_MODEL_PATH).expanduser()
    if model_path.exists():
        _log(f"Whisper model already present at: {model_path}")
        return

    if not config.WHISPER_AUTO_DOWNLOAD:
        raise RuntimeError("Whisper auto-download is disabled.")

    _log(f"Downloading Whisper model '{config.WHISPER_MODEL_SIZE}'...")
    model_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        from faster_whisper import download_model
        download_model(config.WHISPER_MODEL_SIZE, output_dir=str(model_path))
    except Exception as exc:
        raise RuntimeError(f"Whisper download failed: {exc}") from exc


def _check_ollama_hardware(ollama_cmd: str) -> None:
    try:
        # ps muestra los modelos corriendo y el % de gpu que están usando
        result = subprocess.run([ollama_cmd, "ps"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if "100%" in result.stdout:
            _log("Ollama will run on: GPU (100% VRAM)")
        elif "%" in result.stdout:
            _log("Ollama will run on: Híbrido (GPU + CPU)")
        else:
            # Si no ha corrido nada aún, hacemos una consulta general a los componentes
            hw = subprocess.run([ollama_cmd, "run", "llama3.2", "ping"], capture_output=True, text=True, encoding="utf-8", errors="replace")
            # Esto es un poco rudimentario para pre-arranque, pero uvicorn mostrará la info final luego
            _log("Ollama hardware detection complete.")
    except Exception:
        pass


def main() -> None:
    # Forzamos CPU para evitar errores de librerías CUDA (cublas64) faltantes en otros PCs
    os.environ.setdefault("WHISPER_DEVICE", "cpu")

    import config

    ollama_cmd = _ensure_ollama_installed()
    _ensure_ollama_model(ollama_cmd, config.OLLAMA_MODEL)
    _check_ollama_hardware(ollama_cmd)

    if config.WHISPER_AUTO_DOWNLOAD:
        _ensure_whisper_model(config)

    import uvicorn
    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=False,
        log_level="info",
    )


if __name__ == "__main__":
    main()
