# Story 002: Endpoint /stt — Transcripción con faster-whisper

> **Epic**: Proxy Backend
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-backend-001`

**ADR Governing Implementation**: [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: El endpoint `/stt` recibe audio WAV en base64 desde Godot, lo transcribe con faster-whisper modelo `medium`, y retorna el texto. El modelo se carga una vez en startup — no en cada request.

**Engine**: Python 3.x / FastAPI + faster-whisper | **Risk**: LOW
**Engine Notes**: faster-whisper modelo `medium` requiere ~1.5 GB RAM. Confirmar disponibilidad en hardware de prueba. Primera carga tarda ~3s — cargar en startup de la app, no en el handler del endpoint.

---

## Acceptance Criteria

- [ ] `POST /stt` acepta `{"audio": "<base64-encoded WAV>"}` y retorna `{"text": "<transcripción>"}`
- [ ] El modelo faster-whisper `medium` se carga una sola vez al iniciar el servidor (no por request)
- [ ] La transcripción funciona con audio en inglés con acento latino (>85% precisión — verificar en prueba manual)
- [ ] Si el body JSON está malformado o falta el campo `audio`, retorna HTTP 422 con mensaje descriptivo
- [ ] La latencia de transcripción es ≤ 3s para frases de hasta 10 palabras en hardware de prueba (deja margen para LLM en TR-voz-002 que exige ≤ 4s total)

---

## Implementation Notes

*Derivado de ADR-0003 y arquitectura maestra:*

```python
# backend/stt_service.py
from faster_whisper import WhisperModel

# Cargar modelo una vez al importar el módulo
_model = WhisperModel("medium", device="cpu", compute_type="int8")

def transcribe(wav_bytes: bytes) -> str:
    import io
    segments, _ = _model.transcribe(io.BytesIO(wav_bytes), language="en")
    return " ".join(seg.text.strip() for seg in segments)
```

```python
# backend/main.py — agregar a app existente
import base64
from pydantic import BaseModel
from stt_service import transcribe

class STTRequest(BaseModel):
    audio: str  # base64-encoded WAV

@app.post("/stt")
async def stt(req: STTRequest):
    wav_bytes = base64.b64decode(req.audio)
    text = transcribe(wav_bytes)
    return {"text": text}
```

Godot envía el WAV como base64 — el backend decodifica antes de pasar a faster-whisper. `language="en"` forzado para consistencia con TR-voz-002.

---

## Out of Scope

- Story 001: estructura base del servidor (prerequisito)
- Story 003: endpoint `/npc/{id}`
- Grabación de audio en Godot — pertenece a épica `voz-ptt`
- Evaluación de precisión STT — es prueba manual en `/story-done`, no test automatizado

---

## QA Test Cases

- **AC-1**: Endpoint acepta base64 WAV y retorna texto
  - Given: archivo WAV de prueba (frase corta en inglés) codificado en base64
  - When: `POST /stt` con `{"audio": "<base64>"}`
  - Then: HTTP 200; respuesta tiene campo `text` de tipo string no vacío

- **AC-2**: Modelo cargado en startup, no por request
  - Given: servidor iniciado
  - When: verificar que `stt_service._model` no es None antes del primer request
  - Then: `_model` instanciado; tipo `WhisperModel`

- **AC-3**: Input malformado → 422
  - Given: servidor corriendo
  - When: `POST /stt` con body `{}` (sin campo audio)
  - Then: HTTP 422; body contiene descripción del error

- **AC-4**: Input malformado → 422 (base64 inválido)
  - Given: servidor corriendo
  - When: `POST /stt` con `{"audio": "not-valid-base64!!!"}`
  - Then: HTTP 422 o 400; no crash del servidor

- **AC-5**: Latencia ≤ 3s (prueba manual)
  - Setup: grabar frase de 8 palabras en inglés; enviar a `/stt`
  - Verify: tiempo entre request y response
  - Pass condition: ≤ 3000ms en hardware de prueba (i5 o equiv.)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/backend/test_stt.py` — tests automatizados para AC-1, AC-2, AC-3, AC-4; AC-5 es prueba manual documentada en `production/qa/evidence/stt-latency-evidence.md`

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Estructura Base + /health) debe estar DONE
- Unlocks: Epic Core: Voz/PTT puede probarse end-to-end una vez este endpoint funciona
