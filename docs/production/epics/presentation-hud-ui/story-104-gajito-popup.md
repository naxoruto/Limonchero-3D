# Story 104: Popup Gajito

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 2 horas

## Context

**ADR Governing Implementation**: [ADR-0016: Gajito Module](../../../docs/architecture/adr-0016-gajito-module.md)
**ADR Decision Summary**: Popup CanvasLayer layer 15, bottom-left, auto-dismiss 5s, prioridad de mensajes (high/low/hint).

**GDD**: §8.3.2 — Popup Gajito
**UX Spec**: `design/ux/gajito-popup.md`
**Art Bible**: §7.3 — Elementos HUD Overlay, §4.4 — Gajito popup `#7ABE30`

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `GajitoPopup.tscn` como escena (CanvasLayer, layer 15)
- [ ] Posición: bottom-left, 3% de margen desde bordes
- [ ] Ancho máx: 280px (~25% de 1080p)
- [ ] Fondo: `#7ABE30` 85% opacidad, bordes rectos, borde `#6A9E20` 1px
- [ ] Header: "Gajito" bold + icono de limón, texto `#1E1810`
- [ ] Cuerpo: texto de corrección en español, `#1E1810`
- [ ] `show_message(message, severity, duration)` — muestra con fade in 0.2s
- [ ] `dismiss()` — fade out 0.5s
- [ ] Auto-dismiss: 5s para high, 3s para low
- [ ] Queue de prioridad (FIFO dentro de misma prioridad)
- [ ] High reemplaza low (low se descarta)
- [ ] Máx 3 mensajes encolados
- [ ] No se muestra durante diálogo de acusación

## Dependencies

- Story 101 (HUDManager)
- LLM Client Story 003 (grammar_response_received signal)
