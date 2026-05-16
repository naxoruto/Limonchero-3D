# Story 003: Puerta de Confesión

> **Epic**: GameManager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-estado-001`

**ADR Governing Implementation**: [ADR-0001: GameManager como Singleton Autoload](../../../docs/architecture/adr-0001-gamemanager-singleton.md)
**ADR Decision Summary**: `is_confession_gate_open()` retorna `true` solo cuando F1+F2+F3 están simultáneamente en estado `"good"` Y el sospechoso en el intento de acusación actual es `"barry"`. La señal `gate_opened` se emite una sola vez cuando la condición se cumple por primera vez.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `is_confession_gate_open()` retorna `false` si F1, F2 o F3 no están todas en estado `"good"`
- [ ] `is_confession_gate_open()` retorna `false` si F1+F2+F3 están `"good"` pero el sospechoso no es `"barry"`
- [ ] `is_confession_gate_open()` retorna `true` cuando F1+F2+F3 están `"good"` Y sospechoso es `"barry"`
- [ ] La señal `gate_opened` se emite exactamente una vez — la primera vez que la condición se cumple
- [ ] `is_confession_gate_open()` puede ser llamado múltiples veces sin efectos secundarios después de que la puerta está abierta

---

## Implementation Notes

*Derivado de ADR-0001 y CLAUDE.md (`confesion_gate = F1+F2+F3 marked GOOD + Barry named as accused`):*

```gdscript
signal gate_opened()

var _gate_opened_emitted: bool = false

func is_confession_gate_open(suspect: String = "") -> bool:
    var f1_good := get_clue_state("F1") == "good"
    var f2_good := get_clue_state("F2") == "good"
    var f3_good := get_clue_state("F3") == "good"
    var barry_named := suspect.to_lower() == "barry"
    var gate_open := f1_good and f2_good and f3_good and barry_named
    if gate_open and not _gate_opened_emitted:
        _gate_opened_emitted = true
        gate_opened.emit()
    return gate_open
```

Culprit canónico: `"barry"` (minúsculas, sin apellido). Comparar con `.to_lower()` para tolerar variaciones de capitalización del árbol de diálogo.

El módulo Acusación/Final llama `is_confession_gate_open(suspect)` para resolver el caso. No llamar desde otros módulos.

---

## Out of Scope

- Story 002: `set_clue_state()` que pone F1/F2/F3 en `"good"` (prerequisito)
- Story 004: `register_accusation()` — registra el intento independientemente del resultado de la puerta
- El árbol de diálogo de acusación con Commissioner Papolicia — pertenece a la épica Feature: Acusación/Final

---

## QA Test Cases

- **AC-1**: Puerta cerrada con pistas incompletas
  - Given: F1=`"good"`, F2=`"good"`, F3=`"unchecked"`
  - When: `is_confession_gate_open("barry")` llamado
  - Then: retorna `false`; señal `gate_opened` no emitida

- **AC-2**: Puerta cerrada con sospechoso incorrecto
  - Given: F1=`"good"`, F2=`"good"`, F3=`"good"`
  - When: `is_confession_gate_open("moni")` llamado
  - Then: retorna `false`; señal no emitida

- **AC-3**: Puerta abierta — condición completa
  - Given: F1=`"good"`, F2=`"good"`, F3=`"good"`
  - When: `is_confession_gate_open("barry")` llamado
  - Then: retorna `true`; señal `gate_opened` emitida una vez

- **AC-4**: Señal `gate_opened` emitida solo una vez
  - Given: condición completa (F1+F2+F3 good + barry)
  - When: `is_confession_gate_open("barry")` llamado 3 veces seguidas
  - Then: señal emitida exactamente 1 vez en total

- **AC-5**: Tolerancia de capitalización
  - Given: F1+F2+F3 `"good"`
  - When: `is_confession_gate_open("Barry")` llamado
  - Then: retorna `true` (comparación case-insensitive)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/gamemanager_gate_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 002 (Ciclo de Vida de Pistas) debe estar DONE — necesita `get_clue_state()` funcionando
- Unlocks: Epic Feature: Acusación/Final puede implementarse
