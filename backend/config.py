"""
Limonchero 3D — Backend Configuration
Central configuration constants for the FastAPI backend.
"""

# ── Server ──────────────────────────────────────────────
HOST = "0.0.0.0"
PORT = 8000

# ── Ollama / LLM ────────────────────────────────────────
OLLAMA_BASE_URL = "http://localhost:11434"
OLLAMA_MODEL = "llama3.2"
LLM_TIMEOUT_SECONDS = 8  # per GDD §5.2

# ── STT (faster-whisper) ────────────────────────────────
WHISPER_MODEL_SIZE = "medium"
WHISPER_DEVICE = "cuda"        # "cuda" if GPU available, else "cpu"
WHISPER_COMPUTE_TYPE = "float16"  # "float16" for GPU, "int8" for CPU
WHISPER_MODEL_PATH = "~/.cache/limonchero/whisper-medium"
WHISPER_LOCAL_ONLY = True

# ── Grammar (Gajito) ────────────────────────────────────
GRAMMAR_MODEL = OLLAMA_MODEL   # reuse the same Ollama model
