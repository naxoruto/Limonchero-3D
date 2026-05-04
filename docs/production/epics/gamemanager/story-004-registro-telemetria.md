# Story 004: Registro de Eventos de Telemetría

> **Epic**: GameManager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirement**: `TR-telemetria-001`

**ADR Governing Implementation**: [ADR-0007: Telemetría de Sesión](../../../docs/architecture/adr-0007-telemetria-sesion.md)
**ADR Decision Summary**: GameManager acumula telemetría como efecto secundario de operaciones normales. Ningún sistema llama al registrador explícitamente — los módulos llaman los métodos de negocio y GameManager registra internamente. Datos en memoria hasta exportación final.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `register_interrogation(npc_id)` incrementa el contador del NPC en `npcs_interrogated`; si el NPC no existía en el dict, lo inicializa en 1
- [ ] `register_grammar_error()` incrementa `grammar_errors_count` en 1
- [ ] `register_accusation(suspect, evidence, correct)` agrega una entrada a `accusation_attempts` con `{suspect, evidence, correct, timestamp}`
- [ ] Cuando `register_accusation()` recibe `correct=true`, setea `correct_accusation=true` y `completed=true`
- [ ] El `timestamp` en cada intento de acusación es segundos transcurridos desde `session_start_time`, no unix time absoluto
- [ ] `register_accusation()` con `correct=false` no modifica `correct_accusation` ni `completed`

---

## Implementation Notes

*Derivado de ADR-0007:*

```gdscript
func register_interrogation(npc_id: String) -> void:
    if not npcs_interrogated.has(npc_id):
        npcs_interrogated[npc_id] = 0
    npcs_interrogated[npc_id] += 1

func register_grammar_error() -> void:
    grammar_errors_count += 1

func register_accusation(suspect: String, evidence: Array, correct: bool) -> void:
    var elapsed := Time.get_unix_time_from_system() - session_start_time
    accusation_attempts.append({
        "suspect": suspect,
        "evidence": evidence.duplicate(),  # evitar referencia compartida
        "correct": correct,
        "timestamp": elapsed
    })
    if correct:
        correct_accusation = true
        completed = true
```

`evidence.duplicate()` previene que el array del intento sea modificado externamente después de registrarlo.

---

## Out of Scope

- Story 001: `initialize_session()` que pone a cero todos los contadores (prerequisito)
- Story 005: `export_session_json()` que lee estos datos para escribir al disco

---

## QA Test Cases

- **AC-1**: `register_interrogation()` inicializa y acumula
  - Given: `npcs_interrogated` vacío
  - When: `register_interrogation("barry")` llamado 3 veces
  - Then: `npcs_interrogated["barry"] == 3`

- **AC-2**: `register_interrogation()` múltiples NPCs independientes
  - Given: `npcs_interrogated` vacío
  - When: `register_interrogation("barry")`, luego `register_interrogation("moni")`
  - Then: `npcs_interrogated["barry"] == 1`, `npcs_interrogated["moni"] == 1`

- **AC-3**: `register_grammar_error()` acumula
  - Given: `grammar_errors_count == 0`
  - When: `register_grammar_error()` llamado 4 veces
  - Then: `grammar_errors_count == 4`

- **AC-4**: `register_accusation()` incorrecto no cambia completed
  - Given: `completed=false`, `correct_accusation=false`
  - When: `register_accusation("moni", ["F3"], false)` llamado
  - Then: `completed == false`, `correct_accusation == false`, `accusation_attempts.size() == 1`

- **AC-5**: `register_accusation()` correcto setea flags
  - Given: `completed=false`
  - When: `register_accusation("barry", ["F1","F2","F3"], true)` llamado
  - Then: `completed == true`, `correct_accusation == true`

- **AC-6**: timestamp relativo a session_start_time
  - Given: `session_start_time` conocido
  - When: `register_accusation(...)` llamado N segundos después de inicializar sesión
  - Then: `accusation_attempts[0]["timestamp"]` ≈ N (diferencia < 1s)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/gamemanager_telemetry_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Story 001 (Inicialización de Sesión) debe estar DONE — `session_start_time` requerido para timestamp relativo
- Unlocks: Story 005 (Exportación JSON) — necesita datos acumulados para exportar
