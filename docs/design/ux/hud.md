# UX Spec: HUD In-Game

> **GDD:** §8.3.2 | **ADR:** ADR-0017 | **TR-ID:** TR-ui-001  
> **Prioridad:** Sprint 2-3 | **Story:** presentation-hud-ui/101, 102, 103, 105  
> **Estado:** Overlay persistente durante gameplay

## Layout

```
┌──────────────────────────────────────────────┐
│ [Mic           ]                              │
│ [Grabando...]   PTTIndicator (top-left)       │
│                                                │
│                                                │
│              .  Crosshair (center)             │
│                                                │
│              ┌──────────────────────┐          │
│              │ [E] Examinar        │          │
│              └──────────────────────┘          │
│           InteractionPrompt (center-bottom)     │
│                                                │
│ ┌──────────────────────────────────────────┐   │
│ │ [Barry Peel]                    [Tú]     │   │
│ │ I signed mine tonight.         I think   │   │
│ │                               you did.  │   │
│ └──────────────────────────────────────────┘   │
│         SubtitlePanel (bottom, 80% width)       │
│                                                │
│ [🏆 pista añadida] (center-top, 1.5s)         │
│                                                │
│ [Gajito: Deberías...] (bottom-left, popup)     │
└──────────────────────────────────────────────┘
```

## Elementos

### 1. Crosshair
- **Posición:** Centro exacto de pantalla
- **Forma:** Punto simple `#E8D5A3`, 4×4px, sin animación
- **Visibilidad:** Siempre visible durante gameplay

### 2. InteractionPrompt
- **Posición:** Centro-inferior, ~15% desde el borde inferior
- **Texto contextual:** `[E] Examinar` / `[E] Interrogar` / `[E] Recoger` / `[E] Abrir`
- **Fuente:** Special Elite 14pt, color `#E8D5A3`
- **Fondo:** `#000000` 50% opacidad, padding 4px
- **Visibilidad:** Solo cuando raycast detecta interactuable en rango (≤2.0m)
- **Transición:** Fade in/out 0.15s

### 3. SubtitlePanel
- **Posición:** Bottom-center, anclado 5% desde borde inferior
- **Ancho:** 80% de pantalla
- **Fondo:** `#000000` 70% opacidad, bordes rectos, sin redondeo
- **NPC Subtitle (canal izquierdo):**
  - Nombre en color de identidad del personaje (ver GDD §8.4)
  - Texto en blanco `#FFFFFF`, Special Elite 14pt
  - Efecto typewriter: 0.03s por carácter
  - Máx 2 líneas, 50 caracteres por línea
- **Player Subtitle (canal derecho):**
  - `[Tú]` en `#87CEEB` (lightblue)
  - Texto en blanco
  - Sin typewriter (aparece completo)
- **Transición:** Fade in 0.15s, fade out 0.3s al terminar frase
- **Visibilidad:** Solo durante diálogo activo con NPC

### 4. PTTIndicator
- **Posición:** Esquina superior-izquierda, ~2% desde bordes
- **Ícono:** Tres barras de audio horizontales, 32×16px
- **Estados:**

| Estado | Ícono | Texto | Color | Comportamiento |
|--------|-------|-------|-------|----------------|
| IDLE | Barras estáticas | — | `#4A4035` (invisible) | Ninguno |
| RECORDING | Barras animadas (onda) | "Grabando..." | `#D4A030` ámbar pulsante | Pulso 0.5s |
| PROCESSING | Barras estáticas | "Gajito pensando..." | `#D4A030` estático | Espera respuesta |

- **Transición entre estados:** Fade 0.15s

### 5. InventoryNotification
- **Posición:** Centro-superior, ~5% desde borde superior
- **Texto:** `"[pista] añadida al inventario"`
- **Fuente:** Special Elite 12pt, color `#E8D5A3`
- **Fondo:** `#000000` 60% opacidad
- **Duración:** 1.5s, luego fade out 0.3s
- **Visibilidad:** Solo cuando `clue_picked` se emite

### 6. AntiStallHint
- **Posición:** Centro-inferior, justo sobre SubtitlePanel
- **Texto:** Hint contextual de Gajito ("Quizás deberías revisar el guardarropa...")
- **Fuente:** Special Elite 12pt, color `#8BC34A` (verde Gajito)
- **Fondo:** `#000000` 50% opacidad
- **Disparo:** L1 (4min) / L2 (5min) / L3 (7min) sin nueva evidencia
- **Duración:** 4s, luego fade out 0.5s
- **Prioridad:** Solo una hint visible a la vez. L3 sobreescribe L2, L2 sobreescribe L1

## Flujo de Señales

```
InteractionSystem.clue_picked(clue_id)
  → GameManager.add_clue(clue_id)
  → GameManager.inventory_changed
  → HUDManager.show_inventory_notification(clue_name)

VoiceManager.recording_started
  → HUDManager.set_ptt_state("recording")

VoiceManager.recording_stopped
  → HUDManager.set_ptt_state("processing")

LLMClient.npc_response_received(npc_id, text)
  → HUDManager.set_ptt_state("idle")
  → HUDManager.show_subtitle_npc(npc_id, text)

LLMClient.grammar_response_received(correction, severity)
  → GajitoPopup.show_message(correction, severity, 5.0)

GameManager.anti_stall_triggered(level)
  → HUDManager.show_anti_stall_hint(level)
```

## Reglas de Visibilidad

- Crosshair: siempre visible durante gameplay
- InteractionPrompt: solo con interactuable en rango
- SubtitlePanel: solo con diálogo activo
- PTTIndicator: IDLE = casi invisible; RECORDING/PROCESSING = visible
- InventoryNotification: 1.5s auto-dismiss
- AntiStallHint: 4s auto-dismiss, solo si no hay diálogo activo
- Todos los elementos se ocultan cuando:
  - Menú de pausa abierto
  - Inventario Tab abierto
  - Overlay de inspección abierto

## Cursor

- **Durante gameplay:** `Input.MOUSE_MODE_CAPTURED`
- **HUD no es interactivo** — solo muestra información. Sin botones.

## Accesibilidad

- Tamaño de subtítulos configurable (12-24pt, default 14pt) desde Settings
- Colores de identidad con respaldo de texto (nombre del personaje siempre visible)
- PTT indicator tiene texto además del ícono (no solo color)
- Contraste mínimo 4.5:1 en todos los textos HUD

## Assets Necesarios

- Mic icon SVG (tres barras, 32×16px, dos variantes: estática + animada)
- Crosshair dot (4×4px, PNG)
- Fondo semi-transparente para panels (shader o textura 1×1px)
- Fuente Special Elite cargada en theme.tres
