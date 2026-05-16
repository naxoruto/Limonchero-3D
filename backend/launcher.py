"""
Limonchero 3D — Bootstrapper
Ensures Ollama + models + Whisper + TTS are available, then starts the backend.
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
LOG_FILE_NAME = "backend.log"
_LOG_FILE_HANDLE = None
OLLAMA_INSTALLER_URL = os.environ.get(
    "OLLAMA_INSTALLER_URL",
    "https://ollama.com/download/OllamaSetup.exe",
)
NVIDIA_WINGET_ID = os.environ.get("NVIDIA_WINGET_ID", "NVIDIA.GeForceExperience")
AUTO_INSTALL_NVIDIA_DRIVER = os.environ.get("AUTO_INSTALL_NVIDIA_DRIVER", "1")


def _log(message: str) -> None:
    print(message, flush=True)


def _resolve_log_path() -> Path:
    if "--log-file" in sys.argv:
        idx = sys.argv.index("--log-file")
        if idx + 1 < len(sys.argv):
            return Path(sys.argv[idx + 1]).expanduser()

    env_path = os.environ.get("LIMONCHERO_LOG_FILE")
    if env_path:
        return Path(env_path).expanduser()

    return BASE_DIR / LOG_FILE_NAME


def _setup_log_file() -> None:
    global _LOG_FILE_HANDLE
    log_path = _resolve_log_path()
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        _LOG_FILE_HANDLE = open(log_path, "a", encoding="utf-8", errors="replace", buffering=1)
    except Exception:
        return
    sys.stdout = _LOG_FILE_HANDLE
    sys.stderr = _LOG_FILE_HANDLE


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


def _ensure_tts_available() -> None:
    """Verify that at least one TTS engine is available for the /tts endpoint.

    Priority:
      1. edge-tts — Microsoft Edge neural TTS (natural voices, requires internet).
      2. pyttsx3 — uses Windows SAPI5 natively (no extra install), wraps espeak on Linux.
      3. espeak-ng / espeak — standalone CLI, common on Linux.

    On Windows, pyttsx3 always works (SAPI5 is built-in) as offline fallback.
    """
    # 1. Try edge-tts (preferred — natural sounding neural voices)
    try:
        import edge_tts
        _log("TTS engine: edge-tts OK (neural voices)")
        return
    except ImportError:
        _log("TTS: edge-tts not installed")

    # 2. Try pyttsx3 (offline fallback — bundled via requirements.txt / PyInstaller)
    try:
        import pyttsx3
        engine = pyttsx3.init()
        _log("TTS engine: pyttsx3 OK (offline fallback)")
        del engine
        return
    except Exception as exc:
        _log(f"TTS: pyttsx3 not available ({exc})")

    # 3. Try espeak-ng / espeak CLI
    for cmd in ["espeak-ng", "espeak"]:
        if _command_exists(cmd):
            _log(f"TTS engine: {cmd} OK")
            return

    # 4. On Linux, try to install espeak-ng automatically
    if not _is_windows():
        _log("TTS: No engine found. Attempting to install espeak-ng...")
        try:
            subprocess.run(
                ["sudo", "apt-get", "install", "-y", "espeak-ng"],
                check=True,
                capture_output=True,
            )
            if _command_exists("espeak-ng"):
                _log("TTS engine: espeak-ng installed successfully.")
                return
        except Exception as exc:
            _log(f"TTS: Auto-install failed ({exc})")

    # 5. Not critical — warn but don't block startup
    _log(
        "⚠️  TTS: No engine available. The /tts endpoint will fail. "
        "Install edge-tts or pyttsx3."
    )


def main() -> None:
    _setup_log_file()
    # Forzamos CPU para evitar errores de librerías CUDA (cublas64) faltantes en otros PCs
    os.environ.setdefault("WHISPER_DEVICE", "cpu")

    import config

    ollama_cmd = _ensure_ollama_installed()
    _ensure_ollama_model(ollama_cmd, config.OLLAMA_MODEL)
    _check_ollama_hardware(ollama_cmd)

    if config.WHISPER_AUTO_DOWNLOAD:
        _ensure_whisper_model(config)

    _ensure_tts_available()

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
