# Story 002: Ciclo de Vida de Pistas y Señales

> **Epic**: GameManager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-estado-001`

**ADR Governing Implementation**: [ADR-0001: GameManager como Singleton Autoload](../../../docs/architecture/adr-0001-gamemanager-singleton.md)
**ADR Decision Summary**: `clues` es el único dict de estado de pistas. Solo modificable vía `add_clue()` y `set_clue_state()` — nunca directamente. Cambios de estado emiten señales tipadas para notificar módulos superiores.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW
**Engine Notes**: Señales tipadas (`signal clue_added(clue_id: String)`) — confirmar que la sintaxis funciona en Godot 4.6 con `.connect()`.

---

## Acceptance Criteria

- [ ] `add_clue(clue_id)` agrega la pista a `clues` con estado inicial `"unchecked"` y timestamp actual; emite `clue_added(clue_id)`
- [ ] `add_clue()` con un `clue_id` ya existente no duplica ni sobreescribe la pista (idempotente)
- [ ] `set_clue_state(clue_id, state)` actualiza el estado de una pista existente a `"good"`, `"not_good"` o `"unchecked"`; emite `clue_state_changed(clue_id, state)`
- [ ] `set_clue_state()` con estado inválido (fuera de los 3 permitidos) no modifica el estado y no emite señal
- [ ] `get_clue_state(clue_id)` retorna el estado actual de la pista, o `""` si no existe
- [ ] Ningún módulo externo puede modificar `clues` directamente sin pasar por los métodos públicos (verificado en code review, no en runtime)

---

## Implementation Notes

*Derivado de ADR-0001:*

```gdscript
signal clue_added(clue_id: String)
signal clue_state_changed(clue_id: String, state: String)

const VALID_STATES := ["good", "not_good", "unchecked"]

func add_clue(clue_id: String) -> void:
    if clues.has(clue_id):
        return  # idempotente
    clues[clue_id] = {
        "state": "unchecked",
        "timestamp": Time.get_unix_time_from_system() - session_start_time
    }
    clue_added.emit(clue_id)

func set_clue_state(clue_id: String, state: String) -> void:
    if not clues.has(clue_id):
        return
    if state not in VALID_STATES:
        return
    clues[clue_id]["state"] = state
    clue_state_changed.emit(clue_id, state)

func get_clue_state(clue_id: String) -> String:
    if not clues.has(clue_id):
        return ""
    return clues[clue_id]["state"]
```

Prefijo `_` no aplicado a `clues` (GDScript no soporta acceso privado real) — la convención de no acceso directo se documenta en CLAUDE.md y se refuerza en code review.

---

## Out of Scope

- Story 001: `initialize_session()` (debe estar DONE antes de esta)
- Story 003: `is_confession_gate_open()` — usa `clues` pero es lógica separada
- Story 004: registro de telemetría de NPCs e interrogatorios

---

## QA Test Cases

- **AC-1**: `add_clue()` agrega con estado inicial correcto
  - Given: `clues` vacío; `session_start_time` inicializado
  - When: `add_clue("F1")` llamado
  - Then: `clues["F1"]["state"] == "unchecked"`, `clues["F1"]["timestamp"] >= 0.0`, señal `clue_added` emitida con arg `"F1"`

- **AC-2**: `add_clue()` idempotente
  - Given: `add_clue("F1")` ya fue llamado con estado `"good"`
  - When: `add_clue("F1")` llamado de nuevo
  - Then: `clues["F1"]["state"]` sin cambios; señal `clue_added` no emitida segunda vez

- **AC-3**: `set_clue_state()` actualiza y emite
  - Given: `clues["F1"]` existe con estado `"unchecked"`
  - When: `set_clue_state("F1", "good")` llamado
  - Then: `get_clue_state("F1") == "good"`; señal `clue_state_changed` emitida con `("F1", "good")`

- **AC-4**: `set_clue_state()` rechaza estado inválido
  - Given: `clues["F1"]` existe con estado `"unchecked"`
  - When: `set_clue_state("F1", "invalid_state")` llamado
  - Then: `get_clue_state("F1") == "unchecked"`; señal no emitida

- **AC-5**: `get_clue_state()` retorna `""` para pista inexistente
  - Given: `clues` vacío
  - When: `get_clue_state("F99")` llamado
  - Then: retorna `""`; sin error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/gamemanager_clues_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Inicialización de Sesión) debe estar DONE
- Unlocks: Story 003 (Puerta de Confesión — usa `get_clue_state()`)
