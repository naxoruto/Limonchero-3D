# Story 109: Pantallas de Resolución del Caso

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 2 horas

## Context

**ADR Governing Implementation**: [ADR-0008: Confession Gate](../../../docs/architecture/adr-0008-confession-gate.md), [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)

**GDD**: §8.3.3 — Pantalla de resolución
**UX Spec**: `design/ux/case-resolution.md`
**Art Bible**: §2.4 — Acusación Final (silencio de Gajito, jazz se corta)

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `CaseResolution.tscn` como CanvasLayer (layer 20)
- [ ] Dos modos: case_resolved (true) y case_failed (false)
- [ ] Caso resuelto: sello BUENA (círculo verde `#2A5A20`) + "CASO RESUELTO" + nombre culpable + evidencias presentadas
- [ ] Caso fallido: sello MALA (círculo rojo `#6A1520` con X) + "CASO FALLIDO" + verdad revelada (Barry)
- [ ] Session ID visible en gris `#7A6A50` (seleccionable Ctrl+C)
- [ ] Botón "Volver al menú principal" → SceneLoader.load("main_menu")
- [ ] No se puede abrir pausa
- [ ] No hay vuelta atrás (no reintentar)
- [ ] Jazz se corta al iniciar (silencio + lluvia — Art Bible §2.4)
- [ ] Gajito no habla durante esta pantalla

## Dependencies

- Story 108 (Accusation Tree)
- GameManager Story 005 (session_id desde export_session_json)
- SceneLoader (volver al menú principal)
