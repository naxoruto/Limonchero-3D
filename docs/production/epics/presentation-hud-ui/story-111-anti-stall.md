# Story 111: Anti-Stall Hints

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 1-2 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)

**GDD**: §8.3.2 — Anti-stall hint
**UX Spec**: `design/ux/hud.md` §6
**Registry**: `anti_stall_L1: 4min`, `anti_stall_L2: 5min`, `anti_stall_L3: 7min`

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `AntiStallHint` como Label dentro de HUDManager (center-bottom, sobre subtítulos)
- [ ] Texto en verde `#8BC34A` (color Gajito), Special Elite 12pt
- [ ] Fondo `#000000` 50% opacidad
- [ ] L1 (4min sin evidencia): hint sutil "Quizás deberías revisar el guardarropa..."
- [ ] L2 (5min): hint más directo "El piso de arriba podría tener respuestas..."
- [ ] L3 (7min): hint explícito "Barry Peel. Su reservado. El acuerdo."
- [ ] Duración: 4s, fade out 0.5s
- [ ] Prioridad: L3 sobreescribe L2, L2 sobreescribe L1
- [ ] No se muestra si hay diálogo activo o menú abierto
- [ ] Timer se pausa cuando el inventario o pausa está abierto

## Dependencies

- Story 101 (HUDManager)
- GameManager Story 003 (anti_stall_triggered signal)
