# Epic: Presentation — HUD/UI

> **Capa**: Presentation (topmost)
> **GDD**: `design/gdd/gdd_detective_noir_vr.md` §8 (UI/UX en PC)
> **Art Bible**: `art/art-bible.md` §7 (UI/HUD Visual Direction)
> **Módulo Arquitectónico**: HUD (architecture.md §3.1)
> **Estado**: Planning
> **Responsable**: Ignacio Cuevas
> **Dependencia de**: GameManager, InteractionSystem, Voice/PTT, LLM Client

## Visión General

Implementa toda la capa de presentación del juego — la interfaz que ve el jugador. Sigue la filosofía **diegética adaptada a PC**: el notebook es un objeto en primer plano, los subtítulos y indicadores van en HUD overlay mínimo, y los menús de sistema usan temperatura opuesta al mundo para señalar "fuera de la investigación".

Tres capas de interfaz (GDD §8.2):

| Capa | Anclaje | Ejemplos |
|------|---------|----------|
| **Diegética** | World-space / SubViewport | Notebook inventario, fotos pistas, reloj pared, tablón diálogo |
| **HUD Overlay** | Screen-space CanvasLayer | Subtítulos, PTT, Gajito popup, prompt interacción, notificaciones |
| **Sistema** | Screen-space (pausa/transición) | Menú principal, pausa, settings, acusación, resolución |

## ADRs Gobernantes

| ADR | Resumen | Riesgo Motor |
|-----|---------|--------------|
| ADR-0017 | **HUD System** — Central autoload, SubtitlePanel (dual-channel typewriter), PTTIndicator (IDLE/RECORDING/PROCESSING), InteractionPrompt, GajitoPopup (layer 15), accesibilidad FOV/font | LOW |
| ADR-0015 | **Inventory Module** — CanvasLayer grid 4×2, 8 slots, color-coded states (BUENA/MALA/SIN_REVISAR), Tab toggle | LOW |
| ADR-0016 | **Gajito Module** — Popup CanvasLayer layer 15, bottom-left, auto-dismiss 5s, priority logic | LOW |
| ADR-0014 | **NPC Dialogue** — Accusation tree UI con Spud, evidence checkboxes, suspect name | LOW |
| ADR-0013 | **Interaction System** — HUD prompt label, inspect overlay CanvasLayer, cursor handling | LOW |
| ADR-0010 | **Diegetic Board** — SubViewport → ViewportTexture → Sprite3D para diálogo NPC en pared | LOW |
| ADR-0008 | **Confession Gate** — Drive accusation UI outcomes (case_resolved / case_failed screens) | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-ui-001 | Subtítulos 2 canales + indicador PTT + overlay Gajito | ADR-0017 ✅ |
| TR-ui-002 | FOV slider 70-110° + tamaño fuente subtítulos configurable | ADR-0017 ✅ |
| TR-interact-002 | Modo inspección — overlay centrado, ESC para cerrar | ADR-0013 ✅ |
| TR-interact-003 | Recogida pista → notificación HUD + inventario | ADR-0013 + ADR-0015 ✅ |
| TR-ui-003 | Notebook diegético con grid 4×2, 8 slots, estados color | ADR-0015 ✅ |
| TR-ui-004 | Popup Gajito auto-dismiss, prioridad de mensajes | ADR-0016 ✅ |
| TR-ui-005 | Acusación: seleccionar evidencias + nombrar acusado | ADR-0014 ✅ |
| TR-ui-006 | Menú principal con health check backend | Story cargador-escena 001 ✅ |
| TR-ui-007 | Pausa: continuar, revisar notas, configuración, salir | ADR-0017 ✅ |
| TR-ui-008 | Pantallas resolución caso (BUENA/MALA + session_id) | ADR-0008 + ADR-0017 ✅ |

## Arquitectura Técnica

### Árbol de Nodos Godot

```
// Autoload: HUDManager (CanvasLayer, layer 10)
HUDManager (CanvasLayer, layer 10)
├── SubtitlePanel (Control, bottom-center, 80% width)
│   ├── NPCSubtitle (RichTextLabel) — name color + typewriter text
│   └── PlayerSubtitle (RichTextLabel) — "[Tú]" lightblue + text
├── PTTIndicator (Control, top-left)
│   ├── MicIcon (TextureRect) — 3 equalized bars
│   └── StatusLabel (Label) — "Grabando..." / "Gajito pensando..."
├── InteractionPrompt (Label, center-bottom) — contextual [E] text
├── InventoryNotification (Label, center-top) — auto-dismiss 1.5s
├── AntiStallHint (Label, center-bottom) — Gajito hints
└── Crosshair (Label, center) — "." punto mínimo

// GajitoPopup (autoload, CanvasLayer, layer 15)
GajitoPopup (CanvasLayer, layer 15)
└── PopupPanel (Panel)
    ├── IconLabel (Label) — "Gajito" en #7ABE30
    └── CorrectionLabel (RichTextLabel) — corrección en español

// InventoryHUD (CanvasLayer, layer 12, shown on Tab)
InventoryTab (CanvasLayer, layer 12)
└── NotebookPanel (Panel, centered 60% screen)
    ├── PageLeft (VBoxContainer) — confirmed facts
    ├── PageDivider (HSeparator) — vertical ink line
    └── PageRight (VBoxContainer) — suspicions
        └── ClueGrid (GridContainer, 4 columns)
            ├── ClueSlot (Panel, per clue)
            │   ├── ClueIcon (TextureRect)
            │   ├── ClueName (Label)
            │   └── ClueStateStamp (Label) — BUENA/MALA/SIN_REVISAR
            └── ...

// System overlays (CanvasLayer, layer 20)
MainMenu (CanvasLayer, layer 20)
PauseMenu (CanvasLayer, layer 20)
SettingsPanel (CanvasLayer, layer 20)
InspectionOverlay (CanvasLayer, layer 20)
AccusationUI (CanvasLayer, layer 20)
CaseResolution (CanvasLayer, layer 20)
```

### Flujo de Señales

```
InteractionSystem                        Voice/PTT
  ├── clue_picked(clue_id) → GameManager   ├── recording_started → HUDManager.PTTIndicator → RECORDING
  └── prompt_changed(text) → HUDManager    └── recording_stopped → HUDManager.PTTIndicator → PROCESSING

GameManager                              LLM Client
  ├── inventory_changed → HUDManager        ├── grammar_response_received → GajitoPopup
  │   └── InventoryTab (via Tab key)        └── npc_response_received → HUDManager.SubtitlePanel
  ├── anti_stall_triggered(Ln) → HUDManager
  └── confession_gate_changed → AccusationUI

Input (PlayerController)
  ├── tab_pressed → toggle InventoryTab
  ├── escape_pressed → toggle PauseMenu
  └── e_pressed (inventory open) → toggle InspectionOverlay
```

## Stories

### Existentes (referenciadas desde otros epics)

| # | Epic origen | Story | Estado | Relación con UI |
|---|-------------|-------|--------|-----------------|
| 1 | Cargador de Escena | 001 — Menú Principal + Health Check | ⬜ Ready | Pantalla de inicio completa (título, health, botón iniciar) |
| 2 | Controlador del Jugador | 002 — FOV en Menú de Opciones | ⬜ Ready | Slider FOV en settings panel, persiste ConfigFile |
| 3 | Sistema de Interacción | 001 — Prompt "Presiona E" | ⬜ Ready | HUD muestra texto contextual (`[E] Examinar`) + crosshair |
| 4 | Sistema de Interacción | 002 — Recogida de Pista → Inventario | ⬜ Ready | HUD notificación 1.5s + señal `inventory_changed` |
| 5 | Sistema de Interacción | 003 — Overlay de Inspección | ⬜ Ready | CanvasLayer centrado con objeto, ESC cerrar, cursor libre |
| 6 | Cliente LLM | 003 — Verificación Gramatical Gajito | ⬜ Ready | HUD escucha `grammar_response_received` → dispara GajitoPopup |
| 7 | GameManager | 003 — Puerta de Confesión | ⬜ Ready | Drive del outcome en pantalla de resolución |
| 8 | GameManager | 005 — Exportación JSON | ⬜ Ready | Muestra session_id en pantalla de cierre |

### Nuevas (por crear en este epic)

| # | Story | Estimado | Depende de | Descripción |
|---|-------|----------|------------|-------------|
| 101 | **HUDManager Autoload** | 3-4h | Interacción 001 | Singleton CanvasLayer + estructura de nodos base. Señales de entrada (recording, prompt, subtitles). Coordina con GameManager. |
| 102 | **Subtítulos Dual-Channel + Typewriter** | 3-4h | Story 101 | NPCSubtitle + PlayerSubtitle con efecto typewriter (0.03s/car), fade in/out, colores de identidad NPC |
| 103 | **Indicador PTT con Estados** | 2-3h | Story 101 + Voz/PTT 001 | IDLE/RECORDING/PROCESSING. Mic icon + StatusLabel. Ámbar pulsante. |
| 104 | **Popup Gajito** | 2h | Story 101 + LLM Client 003 | CanvasLayer layer 15, bottom-left, auto-dismiss 5s, severidad high-only |
| 105 | **Notificación de Inventario** | 1h | Story 101 + Interacción 002 | "[pista] añadida al inventario" center-top, 1.5s, fade |
| 106 | **Inventario Notebook (Tab)** | 4-5h | GameManager 002 | Notebook diegético en CanvasLayer, grid 4×2, 8 slots, estados BUENA/MALA/SIN_REVISAR, sellos, navegación mouse |
| 107 | **Pause Menu + Settings** | 3-4h | Story 101 + Player Controller 002 | ESC → fondo desaturado 60%, panel cuero, opciones: continuar/notas/config/salir. FOV slider, font size, volumen, sensibilidad |
| 108 | **Overlay de Inspección (refinar)** | 2h | Interacción 003 | Integrar con sistema de pistas, zoom con rueda mouse, rotación, botón "Añadir al inventario" |
| 109 | **Árbol de Acusación** | 3-4h | GameManager 003 | Checkboxes evidencia (máx 3), campo nombre acusado, botón "Acusar", confirmación |
| 110 | **Pantallas de Resolución del Caso** | 2h | Story 109 | Caso resuelto (BUENA sello verde + resumen + session_id) / Caso fallido (MALA sello rojo + explicación) |
| 111 | **Godot UI Theme + Fuentes** | 1-2h | — | Crear theme.tres con fuente Special Elite, colores del art bible §4.4, estilos de Label/Button/Panel |
| 112 | **Anti-Stall Hints** | 1-2h | GameManager 003 | HUD escucha `anti_stall_triggered`, muestra hint contextual de Gajito |
| 113 | **Accessibility Pass** | 2-3h | Story 107 | Verificar contraste, respaldo de forma para daltonismo, font scaling, FOV range test |

## Contrato de API (de architecture.md)

```gdscript
# HUDManager (Autoload)
func set_interaction_prompt(text: String, visible: bool) -> void
func show_subtitle_npc(npc_id: String, text: String) -> void
func show_subtitle_player(text: String) -> void
func set_ptt_state(state: String) -> void  # "idle" | "recording" | "processing"
func show_gajito_popup(correction: String, severity: String) -> void
func show_inventory_notification(clue_name: String) -> void
func show_anti_stall_hint(level: int) -> void

signal interaction_prompt_clicked()

# InventoryHUD
func toggle() -> void
func refresh() -> void
func is_open() -> bool

signal inventory_closed()

# GajitoPopup (Autoload)
func show_message(message: String, severity: String, duration: float) -> void
func dismiss() -> void
```

## Cadena de Flujo Crítico

```
Jugador apunta a pista
  → InteractionSystem: prompt_changed("[E] Recoger")
  → HUDManager: set_interaction_prompt("[E] Recoger", true)

Jugador presiona E
  → InteractionSystem: clue_picked(clue_id)
  → GameManager: add_clue(clue_id) → inventory_changed signal
  → HUDManager: show_inventory_notification("[pista] añadida al inventario")

Jugador presiona Tab
  → PlayerController: detecta Tab → InventoryTab.toggle()
  → InventoryHUD: refresh() → consulta GameManager.get_all_clues()
  → Muestra grid 4×2 con estados BUENA/MALA/SIN_REVISAR

Jugador habla (PTT)
  → VoiceManager: recording_started
  → HUDManager: set_ptt_state("recording") → ámbar pulsante + "Grabando..."
  → [audio enviado a backend]
  → VoiceManager: recording_stopped
  → HUDManager: set_ptt_state("processing") → ámbar estático + "Gajito pensando..."

  → LLM Client: grammar_response_received
  → GajitoPopup: show_message(correction, severity, 5.0)

  → LLM Client: npc_response_received
  → HUDManager: show_subtitle_npc(npc_id, text) → typewriter effect
  → HUDManager: set_ptt_state("idle")
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias implementadas, revisadas y cerradas vía `/story-done`
- HUDManager autoload existe y todas las señales de entrada/salida están conectadas
- Subtítulos dual-channel con typewriter funcionan en build exportado
- Indicador PTT muestra los 3 estados correctamente (IDLE/RECORDING/PROCESSING)
- Inventario Tab muestra grid 4×2 con 8 slots y estados BUENA/MALA/SIN_REVISAR
- Gajito popup aparece con auto-dismiss 5s en severity high
- Pause menu + settings (FOV slider 70-110°, font size 12-24pt) funcionales
- Overlay de inspección con rotación de objeto + ESC cierra
- Árbol de acusación: máximo 3 evidencias seleccionables, campo nombre acusado
- Pantallas de resolución del caso (éxito/fracaso) con session_id
- Accesibilidad: contraste 4.5:1 en todos los textos críticos, respaldo de forma para daltonismo
- Godot theme.tres aplicado con Special Elite y paleta art bible
- Todos los CanvasLayer en las capas correctas (HUD=10, Inventory=12, Gajito=15, System=20)

## Siguiente Paso

Ejecutar `/create-stories presentation-hud-ui` para descomponer cada historia pendiente en archivos de story implementables.
