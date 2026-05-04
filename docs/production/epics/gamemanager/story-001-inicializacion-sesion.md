# Story 001: Inicialización de Sesión

> **Epic**: GameManager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: N/A (control-manifest.md no generado aún)
> **Estimate**: 2-3 horas

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-estado-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: [ADR-0001: GameManager como Singleton Autoload](../../../docs/architecture/adr-0001-gamemanager-singleton.md)
**ADR Decision Summary**: GameManager se registra como Autoload singleton en `Project Settings`. Es la única fuente de verdad del estado de juego. `initialize_session()` es el punto de entrada antes de cargar el nivel.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW
**Engine Notes**: `Time.get_datetime_string_from_system()` y `Time.get_unix_time_from_system()` — APIs estables en Godot 4.6. Verificar que el autoload se registra antes de cualquier escena en `project.godot`.

---

## Acceptance Criteria

- [ ] `GameManager` accesible desde cualquier script sin `preload` ni `get_node()` (registrado como Autoload en `project.godot`)
- [ ] `initialize_session(session_id: String, english_level: String)` limpia todo el estado previo y almacena los parámetros recibidos
- [ ] `session_start_time` se registra como unix timestamp en el momento de llamar `initialize_session()`
- [ ] Llamar `initialize_session()` dos veces (reinicio) produce estado limpio, no acumulado
- [ ] Todas las variables de estado tienen valores por defecto seguros antes de llamar `initialize_session()`

---

## Implementation Notes

*Derivado de ADR-0001:*

Registrar `res://scripts/foundation/game_manager.gd` en `Project Settings → Autoload` con el nombre `GameManager`.

```gdscript
extends Node

var session_id: String = ""
var english_level: String = "intermediate"
var session_start_time: float = 0.0
var clues: Dictionary = {}
var npcs_interrogated: Dictionary = {}
var accusation_attempts: Array = []
var grammar_errors_count: int = 0
var anti_stall_triggers: Dictionary = {"L1": 0, "L2": 0, "L3": 0}
var completed: bool = false
var correct_accusation: bool = false
var _session_exported: bool = false
var _timestamp_start: String = ""

func initialize_session(p_session_id: String, p_english_level: String) -> void:
    session_id = p_session_id
    english_level = p_english_level
    session_start_time = Time.get_unix_time_from_system()
    _timestamp_start = Time.get_datetime_string_from_system()
    clues = {}
    npcs_interrogated = {}
    accusation_attempts = []
    grammar_errors_count = 0
    anti_stall_triggers = {"L1": 0, "L2": 0, "L3": 0}
    completed = false
    correct_accusation = false
    _session_exported = false
```

---

## Out of Scope

- Story 002: gestión de pistas (`add_clue`, `set_clue_state`, señales)
- Story 003: lógica de puerta de confesión
- Story 004: métodos de registro de telemetría
- Story 005: exportación JSON al disco

---

## QA Test Cases

- **AC-1**: GameManager accesible sin preload
  - Given: proyecto configurado con GameManager como Autoload
  - When: cualquier script llama `GameManager.session_id`
  - Then: no hay error de null reference; retorna valor por defecto `""`

- **AC-2**: `initialize_session()` limpia estado y guarda parámetros
  - Given: GameManager con estado sucio (clues no vacío, grammar_errors_count > 0)
  - When: `initialize_session("P01", "intermediate")` es llamado
  - Then: `session_id == "P01"`, `english_level == "intermediate"`, `clues == {}`, `grammar_errors_count == 0`

- **AC-3**: `session_start_time` registrado al momento de llamar
  - Given: tiempo actual conocido (mock o medición directa)
  - When: `initialize_session("P01", "beginner")` llamado
  - Then: `session_start_time > 0.0` y refleja el momento de la llamada (diferencia < 1s con `Time.get_unix_time_from_system()`)

- **AC-4**: Doble llamada produce estado limpio
  - Given: `initialize_session("P01", "advanced")` ya fue llamado; se agregó una pista
  - When: `initialize_session("P02", "beginner")` es llamado
  - Then: `clues == {}`, `session_id == "P02"`, sin rastro de sesión anterior

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/gamemanager_init_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: None — primera historia del epic
- Unlocks: Story 002 (ciclo de vida de pistas), Story 003 (puerta de confesión), Story 004 (telemetría), Story 005 (exportación JSON)
