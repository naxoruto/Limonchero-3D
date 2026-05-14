# UX Spec: Pause Menu

> **GDD:** §8.3.3 | **ADR:** ADR-0017 | **TR-ID:** TR-ui-007  
> **Prioridad:** Sprint 3 | **Story:** presentation-hud-ui/107  
> **Estado:** Sistema overlay (pausa el juego)

## Layout

```
┌──────────────────────────────────────────────┐
│              (fondo desaturado 60%           │
│               + desenfoque de profundidad)   │
│                                              │
│         ┌─────────────────────────┐          │
│         │                         │          │
│         │   L I M O N C H E R O  │          │
│         │         3 D            │          │
│         │   ──────────────────   │          │
│         │                         │          │
│         │   ▶ Continuar           │          │
│         │                         │          │
│         │   📓 Revisar notas      │          │
│         │                         │          │
│         │   ⚙ Configuración      │          │
│         │                         │          │
│         │   ──────────────────   │          │
│         │                         │          │
│         │   🚪 Salir al menú     │          │
│         │     principal          │          │
│         │                         │          │
│         └─────────────────────────┘          │
│                                              │
│           (jazz al 15% volumen, filtrado)    │
└──────────────────────────────────────────────┘
```

## Elementos

### Fondo
- **Comportamiento:** El mundo 3D sigue renderizándose
- **Efectos:** Saturación reducida al 60%, desenfoque de profundidad aumentado
- **Temperatura:** Fría-neutra `#C8D0D8` — opuesta al ámbar del juego activo

### Panel
- **Posición:** Centrado, 40% del ancho de pantalla
- **Fondo:** Cuero oscuro `#1A1208`
- **Borde:** `#3D3020` 1px geométrico

### Opciones
| Opción | Acción | Shortcut |
|--------|--------|----------|
| **Continuar** | Cierra pausa, reanuda juego | ESC |
| **Revisar notas** | Abre inventario notebook | Tab (desde pausa) |
| **Configuración** | Abre sub-panel de settings | → |
| **Salir al menú principal** | Confirma → vuelve a main menu | — |

### Salir → Confirmación
- Antes de salir, un sub-diálogo: "¿Volver al menú principal? El progreso no guardado se perderá."
- Opciones: "Sí, salir" (rojo `#8B1A1A`) / "Cancelar"

## Estados

| Estado | Panel | Fondo |
|--------|-------|-------|
| **Closed** | No visible | Juego normal |
| **Paused** | Menú visible con opciones | Fondo desaturado 60% + blur |
| **Settings open** | Panel de settings (reemplaza) | Mismo fondo |
| **Exit confirm** | Diálogo de confirmación sobre panel | Mismo fondo |

## Flujo

```
Jugador presiona ESC
  → PlayerController: detecta ESC
  → PauseMenu.toggle()
  → Si cerrado → open()
    → GameManager.set_paused(true)
    → Fondo: desatura 60% + blur
    → Jazz: baja a 15% volumen, filtrado
    → Mostrar panel
  → Si abierto → close()
    → GameManager.set_paused(false)
    → Fondo: restaurar
    → Jazz: volumen normal
    → Ocultar panel

Jugador click "Continuar"
  → close()

Jugador click "Revisar notas"
  → close()
  → InventoryHUD.open()

Jugador click "Configuración"
  → PauseMenu.hide()
  → SettingsPanel.show()

Jugador click "Salir"
  → Mostrar confirmación
  → Sí → SceneLoader.load("main_menu")
  → Cancelar → volver al menú de pausa
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| ESC pressed | PlayerController → PauseMenu | — |
| Pause opened | PauseMenu → GameManager | paused=true |
| Pause closed | PauseMenu → GameManager | paused=false |
| Exit confirmed | PauseMenu → SceneLoader | "main_menu" path |
| Open settings | PauseMenu → SettingsPanel | — |
| Open inventory | PauseMenu → InventoryHUD | — |

## Reglas de Visibilidad

- ESC abre/cierra pausa
- No se puede abrir pausa durante:
  - Diálogo de acusación (narrativamente prohibido — Art Bible §2.4)
  - Pantalla de resolución del caso
- Abrir pausa durante inspección o inventario → cierra esos overlays primero
- El tiempo narrativo se detiene (anti-stall timer pausado)

## Cursor

- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Hover en opciones:** Cambia color de texto ligeramente (más brillo)
- **Click:** Ejecuta acción

## Accesibilidad

- Navegación por teclado: ↑ ↓ para mover entre opciones, Enter para seleccionar
- Opción "Salir" está separada visualmente (línea) para evitar clics accidentales
- Confirmación de salida requiere acción explícita (Sí/Cancelar)
- Texto `#E8D5A3` sobre `#1A1208` → ratio > 7:1

## Assets Necesarios

- Panel texture (cuero oscuro, tileable o single)
- Iconos: ▶ (continuar), 📓 (notas), ⚙ (config), 🚪 (salir) — outline geométrico `#E8D5A3`
