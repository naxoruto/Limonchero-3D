# Story 002: Petición NPC con Timeout

> **Epic**: Cliente LLM
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-llm-001`, `TR-llm-002`

**ADR Governing Implementation**: [ADR-0002: Ollama LLM exclusivo](../../../docs/architecture/adr-0002-llm-ollama-exclusivo.md), [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: `send_npc_request()` hace POST a `/npc/{id}` con historial + texto del jugador. Timeout 8s implementado con `Timer`. Éxito → `npc_response_received`. Timeout → `request_timeout("npc")`. Error HTTP → `backend_offline`. Nunca bloquea el hilo principal.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW
**Engine Notes**: `HTTPRequest` en Godot 4.6 no tiene timeout nativo — implementar con `Timer` paralelo que cancela el request si expira. `http.cancel_request()` disponible en Godot 4.x.

---

## Acceptance Criteria

- [ ] `send_npc_request(npc_id, history, player_text)` envía `POST /npc/{npc_id}` con body JSON `{"history": [...], "system_prompt": ""}` sin bloquear
- [ ] En respuesta exitosa (HTTP 200), emite `npc_response_received(npc_id, text)` con el campo `response` del JSON
- [ ] Si no hay respuesta en 8s, cancela el request y emite `request_timeout("npc")`
- [ ] Si el backend retorna HTTP ≠ 200 o error de red, emite `backend_offline`
- [ ] Múltiples llamadas simultáneas no interfieren entre sí (cada una crea su propio HTTPRequest hijo)

---

## Implementation Notes

*Derivado de ADR-0002 y ADR-0003:*

```gdscript
func send_npc_request(npc_id: String, history: Array, player_text: String) -> void:
    var http := HTTPRequest.new()
    add_child(http)

    # Timer de timeout — 8s
    var timer := Timer.new()
    add_child(timer)
    timer.one_shot = true
    timer.timeout.connect(func():
        http.cancel_request()
        http.queue_free()
        timer.queue_free()
        request_timeout.emit("npc")
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
        npc_response_received.emit(npc_id, json.get("response", ""))
    , CONNECT_ONE_SHOT)

    var body := JSON.stringify({
        "history": history,
        "system_prompt": ""   # NPC dialogue module sets this — LLMClient is transport only
    })
    var headers := ["Content-Type: application/json"]
    http.request(base_url + "/npc/" + npc_id, headers, HTTPClient.METHOD_POST, body)
```

`system_prompt` vacío aquí — el módulo Diálogo NPC lo construye y lo pasa en `history` o como campo separado. LLMClient es solo transporte.

---

## Out of Scope

- Story 001: estructura base del nodo (prerequisito)
- Story 003: `send_grammar_check()`
- Construcción del system_prompt de cada NPC — pertenece a épica Feature: Diálogo NPC
- Historial de conversación — gestionado por Diálogo NPC, no por LLMClient

---

## QA Test Cases

- **AC-1**: Request enviado sin bloquear
  - Given: mock de HTTPRequest
  - When: `send_npc_request("barry", [], "Hello")` llamado
  - Then: función retorna inmediatamente (no `await`); mock recibió llamada a `.request()`

- **AC-2**: Respuesta exitosa → `npc_response_received`
  - Given: mock HTTPRequest retorna HTTP 200 con `{"response": "I was in my booth."}`
  - When: `send_npc_request("barry", [], "Where were you?")`
  - Then: señal `npc_response_received` emitida con `("barry", "I was in my booth.")`

- **AC-3**: Timeout → `request_timeout("npc")`
  - Given: mock HTTPRequest que nunca responde; `timeout_sec = 0.1` en test
  - When: `send_npc_request(...)` y esperar 0.2s
  - Then: señal `request_timeout` emitida con arg `"npc"`; señal `npc_response_received` NO emitida

- **AC-4**: Error HTTP → `backend_offline`
  - Given: mock HTTPRequest retorna HTTP 503
  - When: `send_npc_request(...)`
  - Then: señal `backend_offline` emitida; señal `npc_response_received` NO emitida

- **AC-5**: Dos llamadas simultáneas no interfieren
  - Given: dos mocks independientes
  - When: `send_npc_request("barry", ...)` y `send_npc_request("moni", ...)` llamados sin await entre ellos
  - Then: dos señales `npc_response_received` emitidas con npc_ids correctos respectivamente

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/foundation/llm_client_npc_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Estructura Base LLMClient) debe estar DONE
- Unlocks: Epic Feature: Diálogo NPC puede implementar flujo completo PTT→STT→LLM→pantalla
