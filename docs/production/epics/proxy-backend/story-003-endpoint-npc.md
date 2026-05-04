# Story 003: Endpoint /npc/{id} — Proxy a Ollama llama3.2

> **Epic**: Proxy Backend
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-backend-001`

**ADR Governing Implementation**: [ADR-0002: Ollama LLM exclusivo](../../../docs/architecture/adr-0002-llm-ollama-exclusivo.md), [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: `POST /npc/{npc_id}` recibe historial de conversación + system_prompt, llama a `ollama.chat()` con `model=llama3.2` y `num_predict=150`. Timeout 8s. Retorna respuesta del NPC como texto. Si timeout, retorna error descriptivo — no crash.

**Engine**: Python 3.x / FastAPI + ollama | **Risk**: LOW
**Engine Notes**: `ollama` Python client es independiente del motor. Confirmar que `ollama.chat()` respeta el timeout configurado — puede requerir `asyncio.wait_for()` ya que la librería ollama no siempre expone timeout nativo.

---

## Acceptance Criteria

- [ ] `POST /npc/{npc_id}` acepta `{"history": [...], "system_prompt": "..."}` y retorna `{"response": "<texto NPC>"}`
- [ ] El historial se convierte a formato messages de Ollama: system_prompt como `role: "system"`, history como alternancia `user`/`assistant`
- [ ] `num_predict: 150` aplicado en todas las llamadas para limitar longitud de respuesta
- [ ] Si la llamada a Ollama supera 8s, retorna HTTP 504 con `{"error": "timeout", "message": "NPC response timed out"}` — sin crash del servidor
- [ ] El `npc_id` en el path se incluye en el log (no se usa para routing de modelo — todos los NPCs usan llama3.2)

---

## Implementation Notes

*Derivado de ADR-0002:*

```python
# backend/llm_service.py
import asyncio
import ollama
import config

async def get_npc_response(system_prompt: str, history: list) -> str:
    messages = [{"role": "system", "content": system_prompt}]
    for turn in history:
        messages.append({"role": turn["role"], "content": turn["content"]})

    response = await asyncio.wait_for(
        asyncio.to_thread(
            ollama.chat,
            model=config.OLLAMA_MODEL,
            messages=messages,
            options={"num_predict": 150}
        ),
        timeout=config.LLM_TIMEOUT_SEC
    )
    return response["message"]["content"]
```

```python
# backend/main.py — agregar a app existente
from fastapi import HTTPException
from pydantic import BaseModel
from llm_service import get_npc_response

class NPCRequest(BaseModel):
    history: list
    system_prompt: str

@app.post("/npc/{npc_id}")
async def npc_endpoint(npc_id: str, req: NPCRequest):
    try:
        text = await get_npc_response(req.system_prompt, req.history)
        return {"response": text}
    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail={"error": "timeout", "message": "NPC response timed out"})
```

El `npc_id` no cambia el modelo — todos los NPCs usan llama3.2. Se incluye en logs para debugging.

---

## Out of Scope

- Story 001: servidor base (prerequisito)
- Story 004: `/grammar` (comparte llm_service pero es endpoint separado)
- System prompts de cada NPC — definidos en Godot, enviados en el body, no almacenados en el backend
- Condicionamiento por nivel de inglés (english_level en system_prompt) — Godot incluye el modificador en `system_prompt` antes de enviar; el backend no lo procesa

---

## QA Test Cases

- **AC-1**: Endpoint retorna respuesta de NPC
  - Given: Ollama corriendo con llama3.2; body con `system_prompt` corto y `history` de 1 turno
  - When: `POST /npc/barry` con `{"history": [{"role": "user", "content": "Hello"}], "system_prompt": "You are Barry."}`
  - Then: HTTP 200; `response.text` es string no vacío

- **AC-2**: Formato messages correcto
  - Given: `system_prompt="You are Barry"`, `history=[{role:"user", content:"Hi"}, {role:"assistant", content:"Hello"}]`
  - When: mock de `ollama.chat` captura el argumento `messages`
  - Then: `messages[0] == {"role": "system", "content": "You are Barry"}`, `messages[1]["role"] == "user"`, `messages[2]["role"] == "assistant"`

- **AC-3**: `num_predict: 150` en cada llamada
  - Given: mock de `ollama.chat`
  - When: cualquier llamada a `/npc/{id}`
  - Then: `options["num_predict"] == 150` en kwargs de la llamada mockeada

- **AC-4**: Timeout → HTTP 504, sin crash
  - Given: mock de `ollama.chat` que duerme > 8s
  - When: `POST /npc/barry` con timeout configurado a 0.1s en test
  - Then: HTTP 504; body `{"detail": {"error": "timeout", ...}}`; servidor sigue respondiendo a requests posteriores

- **AC-5**: Body malformado → 422
  - Given: servidor corriendo
  - When: `POST /npc/barry` con `{}` (sin history ni system_prompt)
  - Then: HTTP 422

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/backend/test_npc.py` — ACs 2/3/4/5 con mocks; AC-1 requiere Ollama real (marcar como `@pytest.mark.requires_ollama`)

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Estructura Base) debe estar DONE
- Unlocks: Epic Feature: Diálogo NPC puede probarse end-to-end
