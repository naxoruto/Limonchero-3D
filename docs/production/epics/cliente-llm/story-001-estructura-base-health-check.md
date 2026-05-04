# Story 001: Estructura Base LLMClient + Health Check

> **Epic**: Cliente LLM
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 horas
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-llm-001`, `TR-llm-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: [ADR-0003: Backend FastAPI proceso separado](../../../docs/architecture/adr-0003-backend-fastapi-proceso-separado.md)
**ADR Decision Summary**: El LLMClient es un Node Godot que encapsula toda comunicación HTTP con FastAPI en localhost:8000. `check_backend_health()` hace hasta 3 reintentos antes de emitir `backend_offline`. Nunca lanza excepción — todos los errores van a señales.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW
**Engine Notes**: `HTTPRequest` es API estable en Godot 4.6. Señal `request_completed(result, code, headers, body)`. Verificar que el nodo se agrega como hijo antes de llamar `.request()`.

---

## Acceptance Criteria

- [ ] `LLMClient` es un `Node` con `var base_url: String = "http://localhost:8000"` y `var timeout_sec: float = 8.0`
- [ ] `check_backend_health()` envía `GET /health` y retorna `true` si recibe HTTP 200
- [ ] `check_backend_health()` reintenta hasta 3 veces con 1s de pausa entre intentos antes de emitir `backend_offline`
- [ ] `backend_offline` se emite si los 3 reintentos fallan — nunca se lanza excepción
- [ ] Todas las señales del contrato están declaradas con tipos explícitos, aunque no se emitan en esta historia

---

## Implementation Notes

*Derivado de ADR-0003:*

```gdscript
# scripts/foundation/llm_client.gd
class_name LLMClient
extends Node

const MAX_HEALTH_RETRIES := 3
const RETRY_INTERVAL_SEC := 1.0

var base_url: String = "http://localhost:8000"
var timeout_sec: float = 8.0

# Señales del contrato completo — emitidas en stories 002 y 003
signal npc_response_received(npc_id: String, response_text: String)
signal grammar_response_received(has_error: bool, correction: String)
signal backend_offline()
signal request_timeout(request_type: String)

func check_backend_health() -> void:
    _health_check_attempt(1)

func _health_check_attempt(attempt: int) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(
        _on_health_response.bind(attempt, http), CONNECT_ONE_SHOT
    )
    http.request(base_url + "/health")

func _on_health_response(result: int, code: int, _headers: PackedStringArray,
        _body: PackedByteArray, attempt: int, http: HTTPRequest) -> void:
    http.queue_free()
    if result == HTTPRequest.RESULT_SUCCESS and code == 200:
        return  # backend disponible — el llamador escucha la ausencia de backend_offline
    if attempt < MAX_HEALTH_RETRIES:
        await get_tree().create_timer(RETRY_INTERVAL_SEC).timeout
        _health_check_attempt(attempt + 1)
    else:
        backend_offline.emit()
```

Nota: `check_backend_health()` no retorna `bool` — es asíncrona por diseño. El llamador escucha la señal `backend_offline` para saber si falló. Si no se emite, el backend está disponible.

---

## Out of Scope

- Story 002: `send_npc_request()` — petición NPC
- Story 003: `send_grammar_check()` — verificación gramatical
- Godot-side `BackendLauncher` (lanzar proceso Python) — pertenece a épica `cargador-escena`

---

## QA Test Cases

- **AC-1**: Constantes y señales correctas
  - Given: `LLMClient.new()` instanciado
  - When: acceder a `base_url`, `timeout_sec`
  - Then: `base_url == "http://localhost:8000"`, `timeout_sec == 8.0`

- **AC-2**: `check_backend_health()` emite `backend_offline` tras 3 fallos
  - Given: mock de HTTPRequest que siempre retorna error (result != SUCCESS)
  - When: `check_backend_health()` llamado
  - Then: señal `backend_offline` emitida exactamente 1 vez; no excepción

- **AC-3**: `check_backend_health()` no emite `backend_offline` si primer intento OK
  - Given: mock de HTTPRequest que retorna HTTP 200
  - When: `check_backend_health()` llamado
  - Then: señal `backend_offline` no emitida

- **AC-4**: Señales declaradas con tipos
  - Given: `LLMClient` script parseado
  - When: verificar declaraciones de señales
  - Then: `npc_response_received`, `grammar_response_received`, `backend_offline`, `request_timeout` presentes y tipadas

- **AC-5**: Nunca lanza excepción
  - Given: backend no disponible (mock de error de red)
  - When: `check_backend_health()` llamado
  - Then: sin `push_error` no capturado; sin crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/llm_client_health_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: None — primera historia del epic
- Unlocks: Story 002 (send_npc_request), Story 003 (send_grammar_check)
