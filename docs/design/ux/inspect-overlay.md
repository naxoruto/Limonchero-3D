# UX Spec: Inspection Overlay

> **GDD:** §8.3.3 | **ADR:** ADR-0013 | **TR-ID:** TR-interact-002  
> **Prioridad:** Sprint 2-3 | **Story:** sistema-interaccion/story-003, presentation-hud-ui/113  
> **Estado:** Sistema overlay (abierto durante inspección)

## Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│   [Cerrar (ESC)]        [Nombre del Objeto]  │
│                                              │
│         ┌──────────────────────────┐         │
│         │                          │         │
│         │                          │         │
│         │     ┌────────────┐      │         │
│         │     │            │      │         │
│         │     │   OBJETO   │      │         │
│         │     │   3D/2D    │      │         │
│         │     │            │      │         │
│         │     └────────────┘      │         │
│         │                          │         │
│         └──────────────────────────┘         │
│          (viewport con objeto centrado)       │
│                                              │
│   Descripción: Lorem ipsum dolor sit amet,   │
│   consectetur adipiscing elit.               │
│                                              │
│   ┌──────────────────────────────┐           │
│   │  Añadir al inventario       │           │
│   └──────────────────────────────┘           │
│                                              │
└──────────────────────────────────────────────┘
```

## Elementos

### Header
- **Botón "Cerrar (ESC)":** Esquina superior-izquierda, texto en `#E8D5A3`
- **Nombre del objeto:** Centro-superior, Special Elite 16pt, color `#E8D5A3`

### Viewport
- **Área:** Centrado, ~60% del ancho de pantalla, ~50% de altura
- **Contenido:** Objeto 3D (SubViewport con cámara orbital) o imagen 2D de la pista
- **Interacción:** Click + arrastrar para rotar (objeto 3D) o mover (imagen 2D). Rueda del mouse para zoom.
- **Fondo:** `#000000` 80% opacidad, con vignette suave
- **Rim light:** `#E8F0F8` pulsante 0.5Hz durante descubrimiento inicial

### Descripción
- **Posición:** Debajo del viewport, centrado
- **Texto:** Special Elite 12pt, color `#E8D5A3`
- **Formato:**
  - Línea 1: Código de evidencia (ej. "EV-F3-escena")
  - Línea 2+: Descripción contextual

### Botón de Acción
- **Label:** "Añadir al inventario" / "Ya en inventario" (desactivado)
- **Estilo:** Borde `#D4A030` 1px, texto `#E8D5A3`, hover resalta
- **Acción:** Emite `add_to_inventory(clue_id)` o cierra overlay si ya está en inventario

## Estados

| Estado | Viewport | Botón | Descripción |
|--------|----------|-------|-------------|
| **Cargando** | Spinner centrado | Desactivado | "Cargando pista..." |
| **Visible (no inventariado)** | Objeto rotable | "Añadir al inventario" activo | Pista no recogida aún |
| **Ya inventariado** | Objeto rotable | "Ya en inventario" gris + check | Solo revisión |
| **Testimonio** | Icono de testimonio (burbuja) + texto | "Ya en inventario" | No requiere "recoger" |

## Flujo

```
Jugador recoge pista (E)
  → InteractionSystem: clue_picked(clue_id)
  → GameManager: add_clue(clue_id)
  → InspectionOverlay.open(clue_id)

Jugador en inventario Tab, click en pista
  → InventoryHUD: inspect_requested(clue_id)
  → InspectionOverlay.open(clue_id)

InspectionOverlay.open(clue_id):
  → Cargar asset de pista en SubViewport
  → Mostrar nombre + descripción
  → Si no inventariado: botón "Añadir al inventario"
  → Si ya inventariado: botón desactivado

Jugador click "Añadir" o presiona E
  → InspectionOverlay: add_to_inventory(clue_id)
  → GameManager: add_clue(clue_id)
  → Cerrar overlay

Jugador presiona ESC
  → Cerrar overlay
  → Restaurar cursor a estado anterior
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Inspect opened | InteractionSystem → InspectionOverlay | clue_id |
| Inspect from inventory | InventoryHUD → InspectionOverlay | clue_id |
| Add to inventory | InspectionOverlay → GameManager | clue_id |
| Inspect closed | InspectionOverlay → PlayerController | — |

## Reglas de Visibilidad

- Se abre automáticamente al recoger una pista por primera vez
- También se abre al hacer click en una pista desde el inventario
- ESC cierra el overlay
- Estando en overlay, el cursor está libre
- El mundo detrás se oscurece pero no se pausa (el tiempo narrativo sigue)
- Solo un overlay de inspección a la vez

## Cursor

- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Comportamiento:** Click+arrastrar para rotar objeto. Rueda para zoom.
- **Botón:** Hover cambia color de borde

## Accesibilidad

- Rotación de objeto: se puede hacer con teclado (← → para rotar, ↑ ↓ para zoom)
- Descripción también disponible como audio label (futuro)
- Texto con contraste ≥ 4.5:1 sobre fondo oscuro
- Botón grande (mín 44px altura) para click fácil

## Assets Necesarios

- SubViewport con cámara orbital (configurable en Godot)
- Spinner de carga (reutilizable del main menu)
- Fondo vignette (shader o textura)
- Icono testimonio para evidencias tipo testimony
