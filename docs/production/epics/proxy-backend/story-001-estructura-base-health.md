# Story 001: Estructura Base FastAPI + Endpoint /health

> **Epic**: Proxy Backend
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-backend-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: FastAPI corre como proceso Python separado en `localhost:8000`. Puerto fijo. Godot lo lanza con `OS.create_process()` y verifica disponibilidad con `/health` antes de habilitar "Iniciar partida".

**Engine**: Python 3.x / FastAPI | **Risk**: LOW
**Engine Notes**: Sin APIs de Godot en esta historia — Python puro. Verificar que `httpx` o `requests` esté disponible para el health check interno a Ollama.

---

## Acceptance Criteria

- [ ] `backend/main.py` arranca con `uvicorn` en `localhost:8000` sin error cuando Ollama está disponible
- [ ] `GET /health` retorna `{"status": "ok", "model": "llama3.2"}` cuando Ollama responde en `localhost:11434`
- [ ] `GET /health` retorna `{"status": "ollama_unavailable"}` con HTTP 200 (no 500) cuando Ollama no está corriendo
- [ ] `backend/config.py` define `OLLAMA_MODEL`, `OLLAMA_BASE_URL`, `LLM_TIMEOUT_SEC`, `PORT` como constantes — sin valores hardcodeados en `main.py`
- [ ] El servidor no crashea si Ollama no está disponible al arrancar

---

## Implementation Notes

*Derivado de ADR-0003:*

```
backend/
├── main.py        ← FastAPI app + routers
├── config.py      ← constantes de configuración
└── requirements.txt
```

```python
# backend/config.py
OLLAMA_MODEL = "llama3.2"
OLLAMA_BASE_URL = "http://localhost:11434"
LLM_TIMEOUT_SEC = 8
PORT = 8000
```

```python
# backend/main.py
from fastapi import FastAPI
import httpx
import config

app = FastAPI()

@app.get("/health")
async def health():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            r = await client.get(f"{config.OLLAMA_BASE_URL}/api/tags")
            if r.status_code == 200:
                return {"status": "ok", "model": config.OLLAMA_MODEL}
    except Exception:
        pass
    return {"status": "ollama_unavailable"}
```

`requirements.txt` mínimo: `fastapi`, `uvicorn[standard]`, `httpx`, `ollama`, `faster-whisper`.

---

## Out of Scope

- Story 002: endpoint `/stt`
- Story 003: endpoint `/npc/{id}`
- Story 004: endpoint `/grammar`
- Godot-side `BackendLauncher` — pertenece a épica `cargador-escena`

---

## QA Test Cases

- **AC-1**: Servidor arranca sin error
  - Given: Ollama disponible en localhost:11434
  - When: `uvicorn backend.main:app --port 8000` ejecutado
  - Then: sin traceback; proceso queda corriendo

- **AC-2**: `/health` retorna `ok` con Ollama disponible
  - Given: Ollama corriendo
  - When: `GET /health` con TestClient de FastAPI
  - Then: `{"status": "ok", "model": "llama3.2"}`, HTTP 200

- **AC-3**: `/health` retorna `ollama_unavailable` sin Ollama
  - Given: Ollama no disponible (mock httpx para simular error de conexión)
  - When: `GET /health`
  - Then: `{"status": "ollama_unavailable"}`, HTTP 200 (no 500)

- **AC-4**: Constantes en config.py
  - Given: `backend/config.py` importado
  - When: acceder a `config.OLLAMA_MODEL`, `config.PORT`, etc.
  - Then: valores son strings/ints no vacíos; no hay `assert` fallido

- **AC-5**: Sin crash si Ollama ausente en startup
  - Given: Ollama no disponible
  - When: importar y crear app FastAPI
  - Then: no hay excepción no capturada; app instanciada correctamente

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/backend/test_health.py` — debe existir y pasar con `pytest`

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: None — primera historia del epic
- Unlocks: Story 002 (stt), Story 003 (npc), Story 004 (grammar) — todas necesitan el servidor base
