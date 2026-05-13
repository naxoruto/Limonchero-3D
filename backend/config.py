"""
Limonchero 3D — Backend Configuration
Central configuration constants for the FastAPI backend.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

# ── Server ──────────────────────────────────────────────
HOST = "0.0.0.0"
PORT = 8000

# ── Ollama / LLM ────────────────────────────────────────
OLLAMA_BASE_URL = "http://localhost:11434"
OLLAMA_MODEL = "llama3.2"
LLM_TIMEOUT_SECONDS = 8  # per GDD §5.2

# ── STT (faster-whisper) ────────────────────────────────
WHISPER_MODEL_SIZE = "small"


def _detect_whisper_device() -> str:
    forced = os.environ.get("WHISPER_DEVICE", "").strip().lower()
    if forced in {"cuda", "cpu"}:
        return forced

    if shutil.which("nvidia-smi") is None:
        return "cpu"

    try:
        subprocess.run(
            ["nvidia-smi", "-L"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.SubprocessError, OSError):
        return "cpu"

    return "cuda"


if getattr(sys, "frozen", False):
	BASE_DIR = Path(sys.executable).resolve().parent
else:
	BASE_DIR = Path(__file__).resolve().parent

WHISPER_DEVICE = _detect_whisper_device()
WHISPER_COMPUTE_TYPE = "float16" if WHISPER_DEVICE == "cuda" else "int8"
WHISPER_MODEL_PATH = os.environ.get(
	"WHISPER_MODEL_PATH",
	str(BASE_DIR / "models" / "whisper-small"),
)
WHISPER_LOCAL_ONLY = True
WHISPER_AUTO_DOWNLOAD = True

# ── Grammar (Gajito) ────────────────────────────────────
GRAMMAR_MODEL = OLLAMA_MODEL   # reuse the same Ollama model
