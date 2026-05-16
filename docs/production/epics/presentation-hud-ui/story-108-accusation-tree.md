# Story 108: Árbol de Acusación

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: [ADR-0014: NPC Dialogue Module](../../../docs/architecture/adr-0014-npc-dialogue-module.md), [ADR-0008: Confession Gate](../../../docs/architecture/adr-0008-confession-gate.md)
**ADR Decision Summary**: Árbol de diálogo scripteado con Papolicia. Checkboxes para evidencias (máx 3), campo texto para nombre acusado. Confession gate: F1+F2+F3 GOOD + accused="barry".

**GDD**: §8.3.3 — Árbol de acusación
**UX Spec**: `design/ux/accusation.md`
**Art Bible**: §2.4 — Acusación Final (silencio de Gajito, sin pausa, jazz se corta)

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Diálogo scripteado con Papolicia (no LLM). Misma línea de apertura siempre.
- [ ] Paso 1: Papolicia pregunta "Who did it, and what's your evidence?"
- [ ] Paso 2: Checkboxes con pistas BUENA (MALA/SIN_REVISAR aparecen grises, no seleccionables)
- [ ] Máximo 3 checkboxes seleccionables simultáneamente
- [ ] Paso 3: Campo de texto para nombre del acusado, con autocomplete de NPC names
- [ ] Paso 4: Confirmación antes de acusar (resumen + Sí/Cancelar)
- [ ] Paso 5: `GameManager.can_confess(accused_name)` determina outcome
- [ ] Si correcto → transición a CaseResolution
- [ ] Si incorrecto → Papolicia feedback "That's not right" + vuelve a paso 1
- [ ] Intentos contados en telemetría (`accusation_attempts`)
- [ ] No se puede abrir pausa durante acusación
- [ ] Cursor libre (MOUSE_MODE_VISIBLE)
- [ ] Si jugador se aleja de Papolicia → diálogo se cancela

## Dependencies

- GameManager Story 003 (can_confess API)
- GameManager Story 004 (telemetría + accusation_attempts)
- InteractionSystem Story 001 (detectar Papolicia como interactuable)
