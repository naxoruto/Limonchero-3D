"""
Limonchero 3D — FastAPI Backend
================================
Proxy server between Godot and AI services (Ollama LLM + faster-whisper STT).

Stories implemented:
  001 — GET  /health          Health check
  002 — POST /stt             Speech-to-text (faster-whisper, model medium)
  003 — POST /npc/{npc_id}    NPC dialogue proxy to Ollama
  004 — POST /grammar         Grammar evaluation for Gajito

Run:
  python main.py
  # or: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import io
import tempfile
import time
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

import ollama
import uvicorn
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

import config
from npc_prompts import (
    NPC_PROMPTS,
    check_barry_confession_gate,
    BARRY_LOCKED_ADDENDUM,
    BARRY_UNLOCKED_ADDENDUM,
)

# ── Logging ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("limonchero-backend")

# ── Lazy-loaded whisper model (heavy — only load on first /stt call) ──
_whisper_model = None


def _ensure_whisper_model(model_path: Path) -> None:
    if model_path.exists():
        return

    if not config.WHISPER_AUTO_DOWNLOAD:
        raise RuntimeError(
            "Whisper model not found at '%s'. Download it first or update "
            "WHISPER_MODEL_PATH." % model_path
        )

    logger.info(
        "Whisper model not found at '%s'. Downloading '%s'...",
        model_path,
        config.WHISPER_MODEL_SIZE,
    )

    model_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        from faster_whisper import download_model
        download_model(config.WHISPER_MODEL_SIZE, output_dir=str(model_path))
    except Exception as e:
        raise RuntimeError("Whisper model download failed: %s" % e) from e


def _resolve_whisper_model_source() -> str:
    if config.WHISPER_MODEL_PATH:
        model_path = Path(config.WHISPER_MODEL_PATH).expanduser()
        if not model_path.exists() and config.WHISPER_LOCAL_ONLY:
            _ensure_whisper_model(model_path)
        if not model_path.exists():
            raise RuntimeError(
                "Whisper model not found at '%s'. Download it first or update "
                "WHISPER_MODEL_PATH." % model_path
            )
        return str(model_path)

    if config.WHISPER_LOCAL_ONLY:
        raise RuntimeError(
            "WHISPER_MODEL_PATH is empty while WHISPER_LOCAL_ONLY is True. "
            "Set WHISPER_MODEL_PATH or disable WHISPER_LOCAL_ONLY."
        )

    return config.WHISPER_MODEL_SIZE


def _get_whisper_model():
    """Lazily load the faster-whisper model on first STT request."""
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel
        model_source = _resolve_whisper_model_source()
        logger.info(
            "Loading faster-whisper model '%s' (device=%s, compute=%s)…",
            model_source,
            config.WHISPER_DEVICE,
            config.WHISPER_COMPUTE_TYPE,
        )
        _whisper_model = WhisperModel(
            model_source,
            device=config.WHISPER_DEVICE,
            compute_type=config.WHISPER_COMPUTE_TYPE,
        )
        logger.info("faster-whisper model loaded successfully.")
    return _whisper_model


def _warm_ollama_model() -> None:
    """Warm up the Ollama model so first NPC/grammar call is fast."""
    try:
        logger.info("Warming up Ollama model '%s'...", config.OLLAMA_MODEL)
        ollama.chat(
            model=config.OLLAMA_MODEL,
            messages=[
                {"role": "system", "content": "Warmup request."},
                {"role": "user", "content": "ping"},
            ],
            options={"num_predict": 1, "temperature": 0.0},
        )
        logger.info("Ollama model warmup complete.")
    except Exception as e:
        logger.warning("Ollama warmup failed: %s", e)


# ── Lifespan ────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle."""
    logger.info("🍋 Limonchero backend starting on port %d", config.PORT)

    # Verify Ollama connectivity
    try:
        ollama.list()
        logger.info("✅ Ollama connection OK (model: %s)", config.OLLAMA_MODEL)
        _warm_ollama_model()
    except Exception as e:
        logger.warning(
            "⚠️  Ollama not reachable at startup: %s — NPC endpoints will fail "
            "until Ollama is available.",
            e,
        )

    yield

    logger.info("🍋 Limonchero backend shutting down.")


# ── FastAPI App ─────────────────────────────────────────
app = FastAPI(
    title="Limonchero 3D Backend",
    description="AI proxy for the Limonchero 3D detective game.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ═══════════════════════════════════════════════════════
#  STORY 001 — Health Check
# ═══════════════════════════════════════════════════════

@app.get("/health")
async def health():
    """
    Health endpoint consumed by Godot's BackendLauncher.
    Returns 200 with status info so the main menu enables "Iniciar partida".
    """
    # Quick Ollama check
    ollama_ok = True
    try:
        ollama.list()
    except Exception:
        ollama_ok = False

    return {
        "status": "ok",
        "model": config.OLLAMA_MODEL,
        "ollama_available": ollama_ok,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ═══════════════════════════════════════════════════════
#  STORY 003 — NPC Dialogue Proxy
# ═══════════════════════════════════════════════════════

class NPCRequest(BaseModel):
    """Request body for /npc/{npc_id}."""
    npc_id: str = Field(..., description="NPC identifier (e.g. 'barry', 'spud')")
    history: list[dict] = Field(
        default_factory=list,
        description="Conversation history: list of {role, content} dicts.",
    )
    message: str = Field(..., description="Player's current message to the NPC.")


class NPCResponse(BaseModel):
    """Response body from /npc/{npc_id}."""
    response: str
    timestamp: str


@app.post("/npc/{npc_id}", response_model=NPCResponse)
async def npc_dialogue(npc_id: str, body: NPCRequest):
    """
    Proxy player message to Ollama with the NPC's hardcoded system prompt.

    CRITICAL (Barry confession gate):
      Barry only confesses if F1 + F2 + F3 evidence markers are present
      in the conversation history.
    """
    npc_key = npc_id.lower().strip()

    if npc_key not in NPC_PROMPTS:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_id}' not found. Valid NPCs: {list(NPC_PROMPTS.keys())}",
        )

    # Build system prompt
    system_prompt = NPC_PROMPTS[npc_key]

    # Barry confession gate — append lock/unlock addendum
    if npc_key == "barry":
        all_messages = body.history + [{"role": "user", "content": body.message}]
        if check_barry_confession_gate(all_messages):
            system_prompt += BARRY_UNLOCKED_ADDENDUM
            logger.info("🔓 Barry confession gate UNLOCKED")
        else:
            system_prompt += BARRY_LOCKED_ADDENDUM
            logger.info("🔒 Barry confession gate LOCKED")

    # Build Ollama messages
    messages = [{"role": "system", "content": system_prompt}]
    for msg in body.history:
        messages.append({
            "role": msg.get("role", "user"),
            "content": msg.get("content", ""),
        })
    messages.append({"role": "user", "content": body.message})

    # Call Ollama
    try:
        logger.info("💬 NPC '%s' — sending %d messages to Ollama", npc_key, len(messages))
        result = ollama.chat(
            model=config.OLLAMA_MODEL,
            messages=messages,
            options={"num_predict": 256},  # keep responses concise for game flow
        )
        response_text = result["message"]["content"]
        logger.info("💬 NPC '%s' responded (%d chars)", npc_key, len(response_text))
    except Exception as e:
        logger.error("Ollama error for NPC '%s': %s", npc_key, e)
        raise HTTPException(
            status_code=503,
            detail=f"LLM service unavailable: {e}",
        )

    return NPCResponse(
        response=response_text,
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


# ═══════════════════════════════════════════════════════
#  STORY 004 — Grammar Evaluation (Gajito)
# ═══════════════════════════════════════════════════════

class GrammarRequest(BaseModel):
    """Request body for /grammar."""
    transcript: str = Field(..., description="The player's spoken text (in English).")
    language: str = Field(default="english", description="Language of the transcript.")


class GrammarResponse(BaseModel):
    """Response body from /grammar."""
    is_correct: bool
    correction: str
    explanation_es: str


GRAMMAR_SYSTEM_PROMPT = (
    "You are an English grammar evaluator for a language-learning detective game. "
    "The player is a native Spanish speaker learning English.\n\n"
    "Analyze the following transcript for grammatical errors.\n"
    "Respond ONLY in this exact JSON format — no markdown, no extra text:\n"
    '{"is_correct": true/false, "correction": "corrected sentence or empty string if correct", '
    '"explanation_es": "brief explanation in Spanish of what was wrong, or empty string if correct"}\n\n'
    "Rules:\n"
    "- Focus on grammar, not content or meaning.\n"
    "- Minor spelling variations are OK if the grammar is correct.\n"
    "- Keep explanations concise (1-2 sentences in Spanish).\n"
    "- If the sentence is correct, set is_correct to true and leave correction/explanation empty."
)


@app.post("/grammar", response_model=GrammarResponse)
async def grammar_check(body: GrammarRequest):
    """
    Evaluate the player's English grammar via Ollama.
    Used by Gajito to provide Spanish-language corrections.
    """
    if not body.transcript.strip():
        return GrammarResponse(is_correct=True, correction="", explanation_es="")

    messages = [
        {"role": "system", "content": GRAMMAR_SYSTEM_PROMPT},
        {"role": "user", "content": f"Transcript: \"{body.transcript}\""},
    ]

    try:
        logger.info("📝 Grammar check: '%s'", body.transcript[:80])
        result = ollama.chat(
            model=config.GRAMMAR_MODEL,
            messages=messages,
            format="json",
            options={"num_predict": 200, "temperature": 0.1},
        )
        raw = result["message"]["content"]
        logger.info("📝 Grammar response: %s", raw[:200])

        # Parse the JSON response from the LLM
        import json
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            # If LLM didn't return valid JSON, treat as correct
            logger.warning("Grammar LLM returned invalid JSON: %s", raw[:200])
            return GrammarResponse(
                is_correct=True,
                correction="",
                explanation_es="",
            )

        return GrammarResponse(
            is_correct=parsed.get("is_correct", True),
            correction=parsed.get("correction", ""),
            explanation_es=parsed.get("explanation_es", ""),
        )

    except Exception as e:
        logger.error("Ollama error for grammar check: %s", e)
        raise HTTPException(
            status_code=503,
            detail=f"Grammar service unavailable: {e}",
        )


# ═══════════════════════════════════════════════════════
#  STORY 002 — Speech-to-Text (STT)
# ═══════════════════════════════════════════════════════

from typing import List

class WordDetail(BaseModel):
    word: str
    probability: int

class STTResponse(BaseModel):
    """Response body from /stt."""
    transcript: str
    duration_ms: int
    clarity_score: int = Field(default=0, description="Pronunciation clarity from 0 to 100")
    words: List[WordDetail] = Field(default_factory=list, description="Word by word pronunciation score")
    language: str = Field(default="en", description="Detected language")


@app.post("/stt", response_model=STTResponse)
async def speech_to_text(file: UploadFile = File(...)):
    """
    Transcribe a WAV audio file using faster-whisper.
    Input: WAV binary file upload.
    Output: Transcript text + processing duration in ms.
    """
    start_time = time.monotonic()

    # Read the uploaded audio into memory
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    logger.info("🎤 STT request: %d bytes", len(audio_bytes))

    try:
        model = _get_whisper_model()

        # Write to a temp file because faster-whisper needs a file path
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_name = tmp.name

        try:
            segments, info = model.transcribe(
                tmp_name,
                # language="en",  # Eliminado para no forzar la traducción y auto-detectar
                beam_size=5,
                best_of=5,
                vad_filter=True,
                word_timestamps=True, # Requerido para obtener la probabilidad por palabra
            )

            # Collect all segment texts and probabilities
            transcript_parts = []
            clarity_sum = 0.0
            word_count = 0
            word_details = []
            
            for segment in segments:
                transcript_parts.append(segment.text.strip())
                if segment.words:
                    for w in segment.words:
                        clarity_sum += w.probability
                        word_count += 1
                        word_details.append(
                            WordDetail(
                                word=w.word.strip(),
                                probability=int(w.probability * 100)
                            )
                        )
                        
            clarity_score = int((clarity_sum / word_count * 100)) if word_count > 0 else 0
        finally:
            # Clean up the temp file after reading
            try:
                import os
                os.remove(tmp_name)
            except OSError:
                pass

        transcript = " ".join(transcript_parts).strip()
        
        transcript = transcript.replace("cisne y el árabe", "cisne y el agave")
        transcript = transcript.replace("Cisne y el Árabe", "Cisne y el Agave")
        transcript = transcript.replace("Cisne y el árabe", "Cisne y el Agave")
        transcript = transcript.replace("pa policia", "papolicia")
        transcript = transcript.replace("pa policía", "papolicia")
        transcript = transcript.replace("pa' policia", "papolicia")
        transcript = transcript.replace("pa' policía", "papolicia")
        transcript = transcript.replace("pa' policia'", "papolicia")
        
        # Whisper a veces confunde el español con árabe u otros idiomas (por la estática o acentos).
        # Para nuestro juego, si no evaluó claramente que es inglés ("en"), sumimos que trató de hablar español.
        detected_lang = "en" if info.language == "en" else "es"
        
        if detected_lang == "es":
            import re
            clean_transcript = transcript.lower()
            tolerated_phrases = [
                "limonchero", "gajito", "moni grana", 
                "brocolini", "cisne y el agave", "papolicia",
            ]
            
            for phrase in tolerated_phrases:
                clean_transcript = clean_transcript.replace(phrase, "")
                
            # Verificar si después de remover las frases toleradas y símbolos queda alguna letra
            remaining = re.sub(r'[^\w\s]', '', clean_transcript).strip()
            
            if not remaining and transcript.strip():
                detected_lang = "en"
                logger.info("El STT detectó español, pero son solo palabras/frases toleradas. Forzando a inglés.")
            else:
                logger.warning("El jugador NO habló en inglés (detectó %s). Asumiendo español.", info.language)
                clarity_score = 0
            
        elapsed_ms = int((time.monotonic() - start_time) * 1000)

        logger.info(
            "🎤 STT result (%dms, clarity: %d%%, lang: %s): '%s'",
            elapsed_ms,
            clarity_score,
            detected_lang,
            transcript[:100],
        )

        return STTResponse(
            transcript=transcript, 
            duration_ms=elapsed_ms, 
            clarity_score=clarity_score,
            words=word_details,
            language=detected_lang
        )

    except Exception as e:
        logger.error("STT error: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"STT processing failed: {e}",
        )


# ═══════════════════════════════════════════════════════
#  Entry Point
# ═══════════════════════════════════════════════════════

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=True,
        log_level="info",
    )
