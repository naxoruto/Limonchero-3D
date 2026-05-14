# UX Spec: Settings Panel

> **GDD:** §8.1, §9.2 | **ADR:** ADR-0017 | **TR-ID:** TR-ui-002  
> **Prioridad:** Sprint 3-4 | **Story:** presentation-hud-ui/107, controlador-jugador/story-002  
> **Estado:** Sub-panel del menú de pausa

## Layout

```
┌──────────────────────────────────────────────┐
│         ┌─────────────────────────┐          │
│         │   C O N F I G U R A C IÓ N        │
│         │                         │          │
│         │  Campo de visión (FOV) │          │
│         │  70 ─────●───── 110    │          │
│         │  [Valor: 85°]          │          │
│         │                         │          │
│         │  Tamaño de subtítulos  │          │
│         │  12 ──●── 24           │          │
│         │  [Tamaño: 14pt]        │          │
│         │                         │          │
│         │  Volumen maestro       │          │
│         │  0 ──────────●── 100   │          │
│         │                         │          │
│         │  Volumen voz (PTT)     │          │
│         │  0 ──────●───── 100    │          │
│         │                         │          │
│         │  Volumen ambiente      │          │
│         │  0 ──●───────── 100    │          │
│         │                         │          │
│         │  Sensibilidad mouse    │          │
│         │  0.1 ────●──── 3.0     │          │
│         │                         │          │
│         │  ┌──────────────────┐  │          │
│         │  │  ← Volver       │  │          │
│         │  └──────────────────┘  │          │
│         └─────────────────────────┘          │
└──────────────────────────────────────────────┘
```

## Elementos

### Panel
- **Posición:** Centrado, 40% del ancho de pantalla
- **Fondo:** Cuero oscuro `#1A1208` (mismo que menú de pausa)

### Controles

| Control | Tipo | Rango | Default | Persiste |
|---------|------|-------|---------|----------|
| **FOV** | Slider horizontal + label numérico | 70–110° | 85° | ✅ |
| **Tamaño subtítulos** | Slider horizontal + label numérico | 12–24pt | 14pt | ✅ |
| **Volumen maestro** | Slider horizontal | 0–100 | 80 | ✅ |
| **Volumen voz (PTT)** | Slider horizontal | 0–100 | 100 | ✅ |
| **Volumen ambiente** | Slider horizontal | 0–100 | 70 | ✅ |
| **Sensibilidad mouse** | Slider horizontal | 0.1–3.0 | 1.0 | ✅ |

### Botón Volver
- **Posición:** Bottom-center del panel
- **Texto:** "← Volver" en `#E8D5A3`
- **Acción:** Cierra SettingsPanel, vuelve a PauseMenu
- **Shortcut:** ESC

## Persistencia

- Todos los valores se guardan en `ConfigFile` (`user://settings.cfg`)
- Se cargan al iniciar el juego (antes del main menu)
- Se aplican en tiempo real (cambiar FOV se ve inmediatamente en el fondo desaturado)
- Al cerrar settings, se guarda automáticamente

## Flujo

```
Desde PauseMenu → click "Configuración"
  → PauseMenu.hide()
  → SettingsPanel.show()
  → Cargar valores desde ConfigFile
  → Mostrar sliders en posición actual

Jugador ajusta slider
  → Aplicar cambio inmediatamente
  → (ej. mover FOV → ver cambio en fondo)

Jugador click "Volver" o ESC
  → Guardar valores a ConfigFile
  → SettingsPanel.hide()
  → PauseMenu.show()
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Open settings | PauseMenu → SettingsPanel | — |
| FOV changed | SettingsPanel → Camera | fov_value (float) |
| Font size changed | SettingsPanel → HUDManager | font_size (int) |
| Volume changed | SettingsPanel → AudioServer | bus, volume (float) |
| Mouse sens changed | SettingsPanel → PlayerController | sensitivity (float) |
| Back clicked | SettingsPanel → PauseMenu | — |
| Settings saved | SettingsPanel → ConfigFile | — |

## Reglas de Visibilidad

- Solo accesible desde menú de pausa
- ESC vuelve al menú de pausa (no cierra directamente)
- El fondo desaturado + blur se mantiene (misma vista que pausa)

## Cursor

- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Sliders:** Click + arrastrar o click directo en la barra
- **Label numérico editable:** Click para editar manualmente

## Accesibilidad

- Sliders navegables con teclado: ← → para ajustar
- Valor numérico visible al lado del slider
- FOV slider con marcas de rango: "70" (izquierda) — "90" (centro) — "110" (derecha)
- Tamaño de subtítulos cambia inmediatamente para previsualizar

## Assets Necesarios

- Slider horizontal texture (barra `#3D3020`, knob `#D4A030`)
- Checkbox texture (cuadrado `#3D3020`, check `#D4A030`)
- Dropdown arrow (triángulo outline)
