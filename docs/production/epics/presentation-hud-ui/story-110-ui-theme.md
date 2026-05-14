# Story 110: UI Theme + Fuentes

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Foundation
> **Estimate**: 1-2 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)

**GDD**: §8.5 — Especificaciones Técnicas de UI (Special Elite, tamaños)
**UX Spec**: `design/ux/typography.md`, `design/ux/iconography.md`
**Art Bible**: §7.4.2 — Tipografía de Sistema

**Engine**: Godot 4 GDScript | **Risk**: LOW
**Engine Notes**: Theme resource aplicado en Project Settings → GUI → Theme. DynamicFont cargado desde .ttf.

---

## Acceptance Criteria

- [ ] `game/assets/fonts/SpecialElite-Regular.ttf` presente (300K, descargado)
- [ ] `game/assets/fonts/theme.tres` creado con DynamicFont para todos los nodos UI
- [ ] Label: Special Elite 14pt, color `#E8D5A3`
- [ ] Button: Special Elite 14pt, colores hover/pressed/disabled
- [ ] Panel: fondo `#0D0D0D` 90% opacidad
- [ ] LineEdit: cursor ámbar `#D4A030`
- [ ] RichTextLabel: Special Elite 14pt, default color `#E8D5A3`
- [ ] CheckBox: Special Elite 14pt
- [ ] HSlider: barra `#3D3020`, grabber `#D4A030`
- [ ] Theme aplicado en Project Settings → General → GUI → Theme
- [ ] Todos los colores coinciden con Art Bible §4.4

## Dependencies

- Ninguna (se puede hacer en paralelo a todo)
