# Epic: Controlador del Jugador

> **Capa**: Core
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: Controlador del Jugador
> **Estado**: Ready
> **Historias**: No creadas aún — ejecutar `/create-stories controlador-jugador`

## Visión General

Implementa el controlador FPS del jugador usando `CharacterBody3D` + `Camera3D`. Gestiona movimiento WASD, rotación de cámara con mouse, sprint con Shift/L3, y captura/liberación del cursor. Soporte para mando (gamepad). Habilita/deshabilita input cuando otros sistemas toman control (overlay de inspección, diálogo, pausa). Verifica sensibilidad de mouse en Linux y Windows antes de demo.

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0012 | CharacterBody3D + Camera3D; `MOUSE_SENSITIVITY` configurable; `enable_input(false)` libera cursor | LOW |
| ADR-0005 | Comunicación hacia capas superiores solo por señales — no `get_node()` cross-layer | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-jugador-001 | Movimiento FPS — CharacterBody3D + Camera3D, WASD/mouse + mando | ADR-0012 ✅ |
| TR-jugador-002 | Sprint (Shift teclado / L3 mando) | ADR-0012 ✅ |

## Contrato de API (de architecture.md)

```gdscript
# Controlador del Jugador
# Expone: señal interacted(target) — para que InteractionSystem escuche
# Consume: Input (teclado/mando)
# APIs motor: CharacterBody3D, Camera3D, Input

func enable_input(enabled: bool) -> void  # Usado por Overlay, Pausa, Diálogo

signal interacted(target: Node3D)
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- Movimiento WASD + rotación mouse funciona en Linux y Windows
- Sprint activa velocidad aumentada mientras se mantiene Shift/L3
- `enable_input(false)` captura/libera cursor correctamente
- No hay cursor visible durante gameplay normal
- Sensibilidad de mouse verificada en build exportado (no solo editor)

## Siguiente Paso

Ejecutar `/create-stories controlador-jugador`
