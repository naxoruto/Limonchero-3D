# Epic: GameManager

> **Capa**: Foundation
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: GameManager (autoload singleton)
> **Estado**: Ready
> **Historias**: 5 historias — ver tabla abajo

## Visión General

Implementa el singleton autoload `GameManager` como única fuente de verdad del estado de juego. Gestiona el estado canónico de pistas (F1–F5), la puerta de confesión, el nivel de inglés, el session_id, contadores de telemetría, y la exportación JSON al finalizar. Ningún otro módulo escribe estado de juego directamente — todo pasa por los métodos públicos de GameManager. La comunicación hacia capas superiores ocurre exclusivamente mediante señales (ADR-0005).

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0001 | GameManager como Node autoload singleton; `clues` solo modificable vía `add_clue()` / `set_clue_state()` | LOW |
| ADR-0005 | Comunicación entre capas exclusivamente por señales; prohibido `get_node()` cross-layer | LOW |
| ADR-0007 | Telemetría JSON: campos canónicos, flag `_session_exported`, exportación en `case_resolved` + `tree_exiting` | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-estado-001 | GameManager autoload: estado de pistas, progreso, flags de progresión | ADR-0001 ✅ |
| TR-telemetria-001 | Registra eventos con marca de tiempo durante la sesión | ADR-0007 ✅ |
| TR-telemetria-002 | Exportación JSON al terminar partida o al salir | ADR-0007 ✅ |
| TR-telemetria-003 | Campos: session_id, english_level, duración, clues, npcs, acusaciones, grammar_errors, anti_stall_triggers, completed, correct_accusation | ADR-0007 ✅ |

## Contrato de API (de architecture.md)

```gdscript
# Variables canónicas
var english_level: String          # "beginner" | "intermediate" | "advanced"
var session_id: String
var clues: Dictionary              # { clue_id: { state, timestamp } }
var npcs_interrogated: Dictionary
var accusation_attempts: Array
var grammar_errors_count: int
var anti_stall_triggers: Dictionary  # {"L1": int, "L2": int, "L3": int}
var completed: bool
var correct_accusation: bool
var session_start_time: float

# Métodos públicos
func add_clue(clue_id: String) -> void
func set_clue_state(clue_id: String, state: String) -> void  # "good"|"not_good"|"unchecked"
func get_clue_state(clue_id: String) -> String
func is_confession_gate_open() -> bool
func register_interrogation(npc_id: String) -> void
func register_grammar_error() -> void
func register_accusation(suspect: String, evidence: Array, correct: bool) -> void
func export_session_json() -> void

# Señales
signal clue_added(clue_id: String)
signal clue_state_changed(clue_id: String, state: String)
signal gate_opened()
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- `GameManager` pasa como autoload en `project.godot`
- `add_clue()` / `set_clue_state()` son los únicos escritores de `clues` — verificado en code review
- `is_confession_gate_open()` retorna `true` solo con F1+F2+F3 en estado `"good"` + Barry nombrado
- `export_session_json()` produce JSON válido con todos los campos TR-telemetria-003
- Flag `_session_exported` previene doble exportación
- Historias de lógica tienen archivos de test en `tests/`

## Historias

| # | Historia | Tipo | Estado | ADR |
|---|----------|------|--------|-----|
| 001 | [Inicialización de Sesión](story-001-inicializacion-sesion.md) | Logic | Ready | ADR-0001 |
| 002 | [Ciclo de Vida de Pistas y Señales](story-002-ciclo-vida-pistas.md) | Logic | Ready | ADR-0001 |
| 003 | [Puerta de Confesión](story-003-puerta-confesion.md) | Logic | Ready | ADR-0001 |
| 004 | [Registro de Eventos de Telemetría](story-004-registro-telemetria.md) | Logic | Ready | ADR-0007 |
| 005 | [Exportación JSON al Disco](story-005-exportacion-json.md) | Integration | Ready | ADR-0007 |

## Siguiente Paso

Ejecutar `/story-readiness production/epics/gamemanager/story-001-inicializacion-sesion.md` para comenzar implementación.
