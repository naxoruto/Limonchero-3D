# UX Spec: Main Menu

> **GDD:** §8.3.3 | **ADR:** ADR-0017 | **TR-ID:** TR-ui-006  
> **Prioridad:** Sprint 1 | **Story:** cargador-escena/story-001  
> **Estado de la pantalla:** Menú de sistema (pre-gameplay)

## Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│              ┌──────────────┐                │
│              │              │                │
│              │  CONCEPT ART │                │
│              │  (club noir) │                │
│              │              │                │
│              └──────────────┘                │
│                                              │
│          ░░░ L I M O N C H E R O ░░░         │
│          ░░░░░░░░ 3 D ░░░░░░░░░░            │
│                                              │
│         ┌─────────────────────────┐          │
│         │  ID de sesión:          │          │
│         │  [________________]     │          │
│         └─────────────────────────┘          │
│                                              │
│         ┌─────────────────────────┐          │
│         │   Iniciar Investigación │          │
│         └─────────────────────────┘          │
│                                              │
│          Estado backend: ● Conectado         │
│                                              │
│         ┌─────────────────────────┐          │
│         │   Salir                 │          │
│         └─────────────────────────┘          │
│                                              │
└──────────────────────────────────────────────┘
```

## Estados

| Estado | Visual | Acción del jugador |
|--------|--------|-------------------|
| **Cargando** | Logo centrado, spinner sutil, fondo negro | Ninguna (auto-resuelve) |
| **Health check OK** | "● Conectado" en verde `#2A5A20`, botón "Iniciar" activo | Click "Iniciar" → carga nivel |
| **Health check FAIL** | "✖ Servidor no disponible" en rojo `#6A1520`, "Reintentar" link visible, botón "Iniciar" gris (desactivado) | Click "Reintentar" → re-check. Click "Salir" → cierra juego |
| **Health check timeout** | "⏱ Sin respuesta del servidor (8s)" en ámbar `#D4A030`, "Reintentar" link | Idem FAIL |
| **Checkeando** | "◌ Verificando servidor..." en texto secundario `#7A6A50` | Botones desactivados |
| **Input vacío** | Campo session_id con placeholder "ID de sesión", botón "Iniciar" gris | Escribir en campo |
| **Input válido** | Campo session_id con texto, botón "Iniciar" activo | Presiona Enter o click "Iniciar" |

## Flujo

```
App launch → Mostrar logo (1.5s) → [checkeando backend]
                                        │
                                   ┌────┴────┐
                                   │  ¿Live? │
                                   └────┬────┘
                                       │
                              ┌────────┴────────┐
                              │ Sí              │ No
                              ▼                 ▼
                        Menu ready       Error state
                        "Iniciar" activo  "Reintentar"
                              │
                        Jugador escribe
                        session_id + click
                        "Iniciar"
                              │
                              ▼
                        SceneLoader.load(
                        "el_agave_y_la_luna")
                        → fade out 0.3s
                        → loading screen
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| App started | `main.gd` → MainMenu | — |
| Health OK | Backend → MainMenu | `{status: "ok"}` |
| Health FAIL | Backend → MainMenu | `{error: String}` |
| Start clicked | MainMenu → SceneLoader | session_id como String |
| Retry clicked | MainMenu → Backend | — |
| Exit clicked | MainMenu → OS | `get_tree().quit()` |

## Reglas de Visibilidad

- Visible al iniciar el juego (escena raíz)
- No hay forma de volver al menú principal durante gameplay excepto desde el menú de pausa ("Salir al menú principal")
- El fondo es arte conceptual estático del club (no 3D en tiempo real)
- Session ID se genera como UUID si el campo está vacío al hacer clic en "Iniciar"

## Cursor

- **Visible:** Sí (menú de sistema)
- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Comportamiento:** Cursor libre, hover en botones cambia color ligeramente

## Accesibilidad

- Contraste: texto `#E8D5A3` sobre fondo `#0D0D0D` → ratio > 13:1
- Botones tienen feedback visual al hover (borde 1px `#D4A030`)
- Estado del backend tiene icono + texto (no solo color)
- Session ID campo soporta pegado (Ctrl+V)

## Assets Necesarios

- Fondo de arte conceptual (1920×1080, PNG, desaturado)
- Logo "LIMONCHERO 3D" en tipografía Special Elite
- Icono de estado (círculo verde/rojo/ámbar, 12×12px)
- Spinner de carga (animación de 8 frames, 32×32px)
