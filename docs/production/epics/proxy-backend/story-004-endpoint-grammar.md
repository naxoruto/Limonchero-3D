# Story 004: Endpoint /grammar — Evaluación Gajito

> **Epic**: Proxy Backend
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-backend-001`

**ADR Governing Implementation**: [ADR-0002: Ollama LLM exclusivo](../../../docs/architecture/adr-0002-llm-ollama-exclusivo.md), [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: `POST /grammar` evalúa el texto del jugador con Ollama (mismo llama3.2) y determina si hay error gramatical. Retorna `{"error": bool, "correction": string}`. Corre en paralelo con `/npc/{id}` — es un request independiente.

**Engine**: Python 3.x / FastAPI + ollama | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `POST /grammar` acepta `{"text": "<texto del jugador>"}` y retorna `{"error": bool, "correction": string}`
- [ ] Si el texto es gramaticalmente correcto, `error=false` y `correction=""` (string vacío, no null)
- [ ] Si hay error gramatical, `error=true` y `correction` contiene la versión corregida en español (o la frase correcta en inglés con explicación en español)
- [ ] Si Ollama tarda más de 8s, retorna HTTP 504 — sin crash
- [ ] Si `text` está vacío o falta el campo, retorna HTTP 422

---

## Implementation Notes

*Derivado de ADR-0002 y arquitectura maestra (pipeline de Gajito):*

```python
# backend/llm_service.py — agregar función
GRAMMAR_SYSTEM_PROMPT = (
    "You are a Spanish-language English grammar evaluator. "
    "The user will send an English phrase spoken by a Spanish-speaking learner. "
    "If the phrase is grammatically correct, respond ONLY with: CORRECT\n"
    "If it has errors, respond with: ERROR\n[corrected phrase]\n[brief explanation in Spanish]"
)

async def evaluate_grammar(text: str) -> dict:
    messages = [
        {"role": "system", "content": GRAMMAR_SYSTEM_PROMPT},
        {"role": "user", "content": text}
    ]
    try:
        response = await asyncio.wait_for(
            asyncio.to_thread(
                ollama.chat,
                model=config.OLLAMA_MODEL,
                messages=messages,
                options={"num_predict": 80}
            ),
            timeout=config.LLM_TIMEOUT_SEC
        )
        content = response["message"]["content"].strip()
        if content.startswith("CORRECT"):
            return {"error": False, "correction": ""}
        else:
            correction = content.removeprefix("ERROR").strip()
            return {"error": True, "correction": correction}
    except asyncio.TimeoutError:
        raise  # re-raise para que el endpoint lo capture
```

```python
# backend/main.py — agregar a app existente
class GrammarRequest(BaseModel):
    text: str

@app.post("/grammar")
async def grammar_endpoint(req: GrammarRequest):
    if not req.text:
        raise HTTPException(status_code=422, detail="text field cannot be empty")
    try:
        result = await evaluate_grammar(req.text)
        return result
    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail={"error": "timeout"})
```

El prompt del evaluador está en el backend — Godot no envía system_prompt para grammar (a diferencia de `/npc/{id}`).

---

## Out of Scope

- Story 003: `/npc/{id}` — comparte `llm_service.py` pero es endpoint independiente
- Pop-up de Gajito en Godot — pertenece a épica Feature: Asistente Gajito
- Definición del prompt gramatical exacto — el prompt de arriba es punto de partida; ajustar en pruebas manuales

---

## QA Test Cases

- **AC-1**: Texto correcto → `error=false`, `correction=""`
  - Given: mock de `ollama.chat` que retorna `"CORRECT"`
  - When: `POST /grammar` con `{"text": "I went to the store yesterday"}`
  - Then: `{"error": false, "correction": ""}` HTTP 200

- **AC-2**: Texto con error → `error=true`, `correction` no vacío
  - Given: mock de `ollama.chat` que retorna `"ERROR\nI went to the store yesterday\nUsa 'went' no 'go'"`
  - When: `POST /grammar` con `{"text": "I go to the store yesterday"}`
  - Then: `{"error": true, "correction": "I went to the store yesterday\nUsa 'went' no 'go'"}` HTTP 200

- **AC-3**: `correction` nunca es null — siempre string
  - Given: cualquier respuesta válida de Ollama (mock)
  - When: `POST /grammar`
  - Then: `response["correction"]` es `str`, no `None`

- **AC-4**: Timeout → HTTP 504, sin crash
  - Given: mock que duerme > timeout
  - When: `POST /grammar`
  - Then: HTTP 504; servidor sigue operativo

- **AC-5**: Campo `text` vacío → 422
  - Given: servidor corriendo
  - When: `POST /grammar` con `{"text": ""}`
  - Then: HTTP 422

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/backend/test_grammar.py` — todos los ACs con mocks de `ollama.chat`

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Estructura Base) debe estar DONE; Story 003 (llm_service.py creado) recomendado primero pero no bloqueante — puede implementarse en paralelo
- Unlocks: Epic Feature: Asistente Gajito puede probarse end-to-end
