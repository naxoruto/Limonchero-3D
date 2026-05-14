# UX Spec: Inventory Notebook (Tab)

> **GDD:** §8.3.1 | **ADR:** ADR-0015 | **TR-ID:** TR-ui-003  
> **Prioridad:** Sprint 3 | **Story:** presentation-hud-ui/106  
> **Estado:** Sistema overlay diegético (abierto con Tab)

## Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│        ┌────────────────────────────┐        │
│        │   ──────────────────────   │        │
│        │   L I M O N C H E R O     │        │
│        │      ┌───┐ ┌───┐          │        │
│        │      │📷 │ │📄 │          │        │
│        │      │F1 │ │T1 │          │        │
│        │      │Acu│ │Inf│          │        │
│        │      │uer│ │Pre│          │        │
│        │      │do │ │lim│          │        │
│        │      └───┘ └───┘          │        │
│        │      ┌───┐ ┌───┐          │        │
│        │      │🔑 │ │📷 │          │        │
│        │      │F2 │ │F4 │          │        │
│        │      │Lla│ │Mal│          │        │
│        │      │ve │ │eta│          │        │
│        │      │   │ │   │          │        │
│        │      └───┘ └───┘          │        │
│        │      ┌───┐ ┌───┐          │        │
│        │      │🔥 │ │📄 │          │        │
│        │      │F3 │ │F5 │          │        │
│        │      │Enc│ │Car│          │        │
│        │      │end│ │ta │          │        │
│        │      │edor│ │   │          │        │
│        │      └───┘ └───┘          │        │
│        │   ──────────────────────   │        │
│        │   HECHOS   │  SOSPECHAS   │        │
│        │   columna  │  columna     │        │
│        │   izq.     │  der.        │        │
│        └────────────────────────────┘        │
│                                              │
└──────────────────────────────────────────────┘
```

## Elementos

### Notebook Frame
- **Posición:** Centrado, ~65% del ancho de pantalla, ~80% de altura
- **Fondo:** Piel de cuero `#3D2510` (borde exterior), páginas `#F5ECC8` (interior)
- **Textura:** Desgaste geométrico en bordes (sin suavizado)
- **Forma:** Rectangular con cantos rectos (sin redondeos)

### Header
- **Texto:** "LIMONCHERO 3D" en Special Elite 18pt, color `#2A1A08`
- **Línea separadora:** Tinta `#2A1A08`, 1px

### Clue Grid (4 columnas × 2 filas = 8 slots)
- **Layout:** GridContainer, 4 columnas, espaciado 12px
- **Slot size:** ~120×90px cada uno
- **Slot visual:**
  - Marco de foto blanco `#F0EDE0`, 4mm de grosor, con sombra sutil
  - Imagen en escala de grises/sepia (100% desaturada)
  - Sello de estado: BUENA (`#2A5A20`, círculo) / MALA (`#6A1520`, círculo con X) / SIN_REVISAR (sin sello)
  - Etiqueta con código de evidencia abajo: "F1 — Acuerdo" o "T1 — Informe"
- **Vacío:** Slot con bordes punteados `#A09070` y texto "— vacío —"
- **Click en slot:** Abre InspectionOverlay con esa pista

### Páginas (Hechos vs Sospechas)
- **Divisor:** Línea vertical de tinta `#2A1A08`, 1px, centro del notebook
- **Columna izquierda (HECHOS):** Pistas con estado BUENA
- **Columna derecha (SOSPECHAS):** Pistas SIN_REVISAR o MALA
- **Auto-organización:** Al cambiar estado de una pista (BUENA/MALA), se mueve a la columna correspondiente

## Estados de Pista

| Estado | Sello | Color | Columna |
|--------|-------|-------|---------|
| **SIN_REVISAR** | — | Foto sepia normal | SOSPECHAS |
| **BUENA** | Círculo lleno | Borde verde `#2A5A20`, tinte sepia | HECHOS |
| **MALA** | Círculo con X | Borde rojo `#6A1520`, tinte más oscuro | SOSPECHAS |

## Flujo

```
Jugador presiona Tab
  → PlayerController detecta Tab
  → InventoryHUD.toggle()
  → Si cerrado → open()
    → GameManager.get_all_clues()
    → Clasificar por estado (BUENA/MALA/SIN_REVISAR)
    → Mostrar en grid 4×2
    → Mostrar en columnas correctas
  → Si abierto → close()
  → GameManager.paused = is_open (detiene anti-stall timer)

Jugador click en slot
  → InspectionOverlay.open(clue_id)
  → InventoryHUD.close()

Jugador vuelve a presionar Tab
  → InventoryHUD.close()
  → GameManager.paused = false
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Tab pressed | PlayerController → InventoryHUD | — |
| Inventory opened | InventoryHUD → PlayerController | — |
| Inventory closed | InventoryHUD → PlayerController | — |
| Inspect clue | InventoryHUD → InspectionOverlay | clue_id |
| Refresh inventory | GameManager → InventoryHUD (via signal `inventory_changed`) | — |

## Reglas de Visibilidad

- Se abre con Tab desde cualquier lugar del nivel
- Se cierra con Tab o ESC
- NO se pausa el juego (el tiempo narrativo sigue)
- Los subtítulos HUD se ocultan mientras el inventario está abierto
- No se puede abrir el inventario durante un diálogo de acusación
- Si se abre el menú de pausa mientras el inventario está abierto → inventario se cierra primero

## Cursor

- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Hover en slot:** Borde del slot se resalta ligeramente
- **Click en slot:** Abre InspectionOverlay
- **Click fuera del notebook:** Cierra inventario

## Accesibilidad

- Sellos BUENA/MALA tienen forma (círculo / círculo con X) además de color — requisito de daltonismo del Art Bible §4.5
- Los nombres de pista son texto legible (no solo iconos)
- Se puede navegar con teclado:
  - Tab para mover entre slots
  - Enter para abrir inspección
  - ESC para cerrar
- Fuente sepia `#2A1A08` sobre fondo crema `#F5ECC8` → ratio > 7:1

## Integración con Clue Types

| Tipo | Slot visual | Código ejemplo |
|------|-------------|----------------|
| **Física** (F1-F5) | Foto B/N del objeto + código | F1 — Acuerdo |
| **Testimonio** (T1-T3) | Icono de burbuja de diálogo + texto | T1 — Informe Preliminar |
| **Distractor** (D1-D5) | Foto B/N + borde punteado | D1 — Maleta de Moni |

## Assets Necesarios

- Notebook frame texture (piel cuero, `#3D2510`)
- Página interior texture (papel, `#F5ECC8`)
- Foto frame (borde blanco `#F0EDE0`, 4mm)
- Sello BUENA (círculo verde `#2A5A20`)
- Sello MALA (círculo + X rojo `#6A1520`)
- Slot vacío textura (borde punteado)
- Evidencia tipos icono (testimonio = burbuja, física = foto, distractor = interrogación)
