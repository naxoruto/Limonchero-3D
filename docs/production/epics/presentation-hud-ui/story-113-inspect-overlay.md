# Story 113: Overlay de Inspección (Refinar)

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 2 horas

## Context

**ADR Governing Implementation**: [ADR-0013: Interaction System](../../../docs/architecture/adr-0013-interaction-system.md)
**ADR Decision Summary**: InspectionOverlay como CanvasLayer centrado. SubViewport para objeto 3D o TextureRect para 2D. ESC cierra. Cursor liberado al abrir.

**GDD**: §8.3.3 — Overlay de inspección
**UX Spec**: `design/ux/inspect-overlay.md`
**Art Bible**: §2.3 — Descubrimiento de Pista (vignette, rim light pulsante)

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Overlay centrado con objeto (SubViewport 3D o TextureRect 2D)
- [ ] Header: nombre del objeto (Special Elite 16pt) + botón "Cerrar (ESC)"
- [ ] Descripción debajo del viewport (código evidencia + texto)
- [ ] Botón "Añadir al inventario" si no está inventariado / "Ya en inventario" si ya lo está
- [ ] Click + arrastrar para rotar objeto 3D o mover imagen 2D
- [ ] Rueda del mouse para zoom
- [ ] ESC cierra overlay
- [ ] Cursor libre (MOUSE_MODE_VISIBLE) mientras está abierto
- [ ] Fondo oscurecido (vignette) mientras el overlay está activo
- [ ] Rim light pulsante 0.5Hz en descubrimiento inicial
- [ ] Se abre automáticamente al recoger pista por primera vez
- [ ] También se abre al hacer click en pista desde inventario

## Dependencies

- InteractionSystem Story 003 (base implementation de inspect overlay)
- Story 106 (Inventory — click en slot dispara inspect_requested)
- GameManager Story 002 (add_clue API)
