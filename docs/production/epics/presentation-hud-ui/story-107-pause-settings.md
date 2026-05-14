# Story 107: Pause Menu + Settings

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)
**ADR Decision Summary**: PauseMenu con fondo desaturado 60% + blur. Panel cuero `#1A1208`. Settings: FOV 70-110°, font size 12-24pt. Persistencia ConfigFile.

**GDD**: §8.3.3 — Menú de pausa, Configuración. §9.2 RNF-05 — FOV slider
**UX Spec**: `design/ux/pause-menu.md`, `design/ux/settings.md`
**Art Bible**: §7.4 — Elementos de Sistema, §2.5 — Menú de Pausa

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] ESC abre/cierra PauseMenu (CanvasLayer layer 20)
- [ ] Fondo 3D sigue renderizándose con saturación 60% + blur de profundidad
- [ ] Panel centrado, cuero oscuro `#1A1208`, 40% de ancho
- [ ] Opciones: Continuar, Revisar notas (abre inventario), Configuración, Salir al menú principal
- [ ] "Salir" con confirmación previa (Sí/Cancelar)
- [ ] Settings panel: FOV slider (70-110°), font size (12-24pt), 3 sliders de volumen, sensibilidad mouse
- [ ] Todos los sliders muestran valor numérico
- [ ] Cambios se aplican en tiempo real (FOV visible en fondo)
- [ ] Persistencia: ConfigFile `user://settings.cfg`
- [ ] Navegación por teclado (↑↓ Enter ESC)

## Dependencies

- Story 101 (HUDManager)
- PlayerController Story 002 (FOV slider conectado a cámara)
- SceneLoader (salir al menú principal)
