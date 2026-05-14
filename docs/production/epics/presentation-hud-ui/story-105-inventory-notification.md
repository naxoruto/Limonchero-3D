# Story 105: Notificación de Inventario

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 1 hora

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)
**ADR Decision Summary**: InventoryNotification como Label en HUDManager, auto-dismiss 1.5s.

**GDD**: §8.3.2 — Notificación de inventario
**UX Spec**: `design/ux/hud.md` §5

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `InventoryNotification` como Label dentro de HUDManager (center-top)
- [ ] Texto: `"[pista] añadida al inventario"` con nombre real de la pista
- [ ] Fuente Special Elite 12pt, color `#E8D5A3`
- [ ] Fondo `#000000` 60% opacidad, padding 4px
- [ ] `show(clue_name: String)` — hace visible, espera 1.5s, fade out 0.3s
- [ ] Si llega otra notificación durante la cuenta regresiva, reinicia el timer
- [ ] No interfiere con otros elementos del HUD

## Dependencies

- Story 101 (HUDManager)
- GameManager Story 002 (inventory_changed signal)
- InteractionSystem Story 002 (clue_picked signal)
