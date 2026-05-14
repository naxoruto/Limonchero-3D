# Story 103: Indicador PTT (3 Estados)

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 2-3 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)
**ADR Decision Summary**: PTTIndicator con 3 estados (IDLE/RECORDING/PROCESSING). Mic icon + StatusLabel. Ámbar pulsante.

**GDD**: §8.3.2 — Indicador PTT
**UX Spec**: `design/ux/hud.md` §4
**Art Bible**: §7.3.3 — Indicador de Voz Activa, §4.4 — PTT activo ámbar `#D4A030`

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `PTTIndicator` como Control dentro de HUDManager (top-left)
- [ ] MicIcon como TextureRect con 3 barras de audio (32×16px)
- [ ] StatusLabel junto al icono (Special Elite 12pt)
- [ ] 3 estados funcionales:

| Estado | Icono | Texto | Color |
|--------|-------|-------|-------|
| IDLE | Barras quietas | — | `#4A4035` |
| RECORDING | Barras animadas (onda) | "Grabando..." | `#D4A030` pulso 0.5s |
| PROCESSING | Barras quietas | "Gajito pensando..." | `#D4A030` estático |

- [ ] `set_state("idle")` / `set_state("recording")` / `set_state("processing")`
- [ ] Transición entre estados con fade 0.15s
- [ ] Estado IDLE es casi invisible (`#4A4035` sobre fondo oscuro)
- [ ] Pulsación de RECORDING implementada con `Tween` (alpha 1.0 → 0.6 → 1.0, loop)

## Dependencies

- Story 101 (HUDManager)
- Voice/PTT Story 001 (recording_started/stopped signals)
- LLM Client Story 002 (npc_response_received → vuelve a IDLE)
