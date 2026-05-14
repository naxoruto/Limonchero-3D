# Story 106: Inventario Notebook (Tab)

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 4-5 horas

## Context

**ADR Governing Implementation**: [ADR-0015: Inventory Module](../../../docs/architecture/adr-0015-inventory-module.md)
**ADR Decision Summary**: CanvasLayer grid 4×2, 8 slots, color-coded states (BUENA/MALA/SIN_REVISAR), Tab toggle. Sin interacción de click en el mundo para recoger.

**GDD**: §8.3.1 — Notebook de inventario
**UX Spec**: `design/ux/inventory.md`
**Art Bible**: §7.2.1 — La Libreta de Notas, §4.4 — Paleta de UI

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `InventoryHUD.tscn` como CanvasLayer (layer 12), se muestra con Tab
- [ ] Notebook visual: fondo cuero `#3D2510`, páginas `#F5ECC8`, texto `#2A1A08`
- [ ] Header "LIMONCHERO 3D" en Special Elite 18pt
- [ ] GridContainer 4 columnas × 2 filas = 8 slots
- [ ] Cada slot: marco foto blanco `#F0EDE0`, imagen desaturada, sello de estado, código evidencia
- [ ] 3 estados de pista con visual distinto (BUENA/MALA/SIN_REVISAR)
- [ ] BUENA → columna HECHOS (izquierda), MALA/SIN_REVISAR → columna SOSPECHAS (derecha)
- [ ] Divisor vertical de tinta entre columnas
- [ ] Click en slot → emite `inspect_requested(clue_id)` → abre InspectionOverlay
- [ ] Slots vacíos: borde punteado `#A09070` + texto "— vacío —"
- [ ] Tab toggle: presionar Tab abre/cierra. ESC también cierra
- [ ] `refresh()` consulta `GameManager.get_all_clues()` y actualiza grid
- [ ] Se oculta al abrir menú de pausa o acusación
- [ ] No se puede abrir durante acusación

## Dependencies

- Story 101 (HUDManager)
- GameManager Story 002 (inventory_changed signal + get_all_clues API)
- InteractionSystem Story 001 (Tab input)
