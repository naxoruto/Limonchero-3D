# Story 003: Verificación Gramatical (Gajito)

> **Epic**: Cliente LLM
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-llm-001`

**ADR Governing Implementation**: [ADR-0002: Ollama LLM exclusivo](../../../docs/architecture/adr-0002-llm-ollama-exclusivo.md), [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: `send_grammar_check()` hace POST a `/grammar` en paralelo con la petición NPC — es un request independiente. Éxito → `grammar_response_received(has_error, correction)`. Timeout → `request_timeout("grammar")`. Mismo patrón de timeout que Story 002.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `send_grammar_check(player_text)` envía `POST /grammar` con body `{"text": player_text}` sin bloquear
- [ ] En respuesta exitosa, emite `grammar_response_received(has_error: bool, correction: String)`
- [ ] `correction` es siempre `String` — nunca `null` (usar `""` si no hay corrección)
- [ ] Si no hay respuesta en 8s, emite `request_timeout("grammar")` — no interrumpe el flujo NPC
- [ ] `send_grammar_check()` y `send_npc_request()` pueden ejecutarse simultáneamente sin interferir

---

## Implementation Notes

*Derivado de ADR-0002 y arquitectura maestra (pipeline paralelo):*

```gdscript
func send_grammar_check(player_text: String) -> void:
    var http := HTTPRequest.new()
    add_child(http)

    var timer := Timer.new()
    add_child(timer)
    timer.one_shot = true
    timer.timeout.connect(func():
        http.cancel_request()
        http.queue_free()
        timer.queue_free()
        request_timeout.emit("grammar")
    )
    timer.start(timeout_sec)

    http.request_completed.connect(func(result, code, _h, body):
        timer.stop()
        timer.queue_free()
        http.queue_free()
        if result != HTTPRequest.RESULT_SUCCESS or code != 200:
            backend_offline.emit()
            return
        var json := JSON.parse_string(body.get_string_from_utf8())
        var has_error: bool = json.get("error", false)
        var correction: String = json.get("correction", "")
        grammar_response_received.emit(has_error, correction)
    , CONNECT_ONE_SHOT)

    var body := JSON.stringify({"text": player_text})
    var headers := ["Content-Type: application/json"]
    http.request(base_url + "/grammar", headers, HTTPClient.METHOD_POST, body)
```

El pipeline de interrogatorio llama `send_npc_request()` y `send_grammar_check()` en el mismo frame — son completamente independientes. El HUD escucha ambas señales por separado.

---

## Out of Scope

- Story 002: `send_npc_request()` (patrón idéntico — no duplicar lógica de timeout)
- Pop-up de corrección en HUD — pertenece a épica Presentation: HUD/UI
- Lógica de cuándo mostrar la corrección — pertenece a épica Feature: Asistente Gajito
- Registro de `grammar_errors_count` — pertenece a GameManager (Story 004 del epic gamemanager)

---

## QA Test Cases

- **AC-1**: Request enviado sin bloquear
  - Given: mock HTTPRequest
  - When: `send_grammar_check("I go to store yesterday")`
  - Then: retorna inmediatamente; mock recibió `.request()` con URL `/grammar`

- **AC-2**: Respuesta con error → `grammar_response_received(true, correction)`
  - Given: mock retorna HTTP 200 con `{"error": true, "correction": "I went to the store yesterday"}`
  - When: `send_grammar_check("I go to store yesterday")`
  - Then: señal emitida con `(true, "I went to the store yesterday")`

- **AC-3**: Respuesta correcta → `grammar_response_received(false, "")`
  - Given: mock retorna HTTP 200 con `{"error": false, "correction": ""}`
  - When: `send_grammar_check("I went to the store yesterday")`
  - Then: señal emitida con `(false, "")`; `correction` es `String` no null

- **AC-4**: Timeout → `request_timeout("grammar")`, flujo NPC no afectado
  - Given: mock grammar nunca responde; `timeout_sec = 0.1`; mock NPC responde normalmente
  - When: ambos llamados simultáneamente
  - Then: `request_timeout("grammar")` emitido; `npc_response_received` emitido normalmente

- **AC-5**: `correction` nunca null
  - Given: mock retorna `{"error": false}` (sin campo `correction`)
  - When: `send_grammar_check(...)`
  - Then: señal emitida con `correction == ""` (string vacío, no null)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/foundation/llm_client_grammar_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Estructura Base LLMClient) debe estar DONE; Story 002 recomendado (patrón reutilizable) pero no bloqueante
- Unlocks: Epic Feature: Asistente Gajito puede implementarse end-to-end
