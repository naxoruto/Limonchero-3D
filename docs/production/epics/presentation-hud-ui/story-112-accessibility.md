# Story 112: Accesibilidad

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: QA
> **Estimate**: 2-3 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)
**ADR Decision Summary**: FOV slider 70-110°, font size configurable 12-24pt. Contraste ≥4.5:1 en todos los textos críticos.

**GDD**: §8.1 (principio 5) — Accesibilidad
**Art Bible**: §4.5 — Seguridad para Daltonismo

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Contraste mínimo 4.5:1 verificado en todos los textos críticos (medir con herramienta de contraste)
- [ ] Sellos BUENA/MALA con respaldo de forma (círculo vs círculo+X) además de color
- [ ] Indicador PTT tiene texto además del icono (no solo color)
- [ ] Todos los NPCs identificables por nombre además de color
- [ ] Navegación por teclado funcional en:
  - Main menu (Tab entre elementos, Enter para acción)
  - Pause menu (↑↓ Enter ESC)
  - Settings (←→ para sliders)
  - Accusation (Tab entre checkboxes, Enter acusar)
  - Inventory (Tab entre slots, Enter inspeccionar)
- [ ] FOV slider rango 70-110° funcional
- [ ] Font size configurable 12-24pt, se aplica a subtítulos inmediatamente
- [ ] Session ID seleccionable (Ctrl+C) en pantalla de resolución

## Dependencies

- Story 107 (Pause/Settings — FOV y font size sliders)
- Story 106 (Inventory — sellos y navegación)
- Story 108 (Accusation — navegación teclado)
- Story 109 (Case Resolution — session ID)
