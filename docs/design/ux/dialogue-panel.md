# UX Spec: Dialogue Panel

> **GDD:** §8.3.2 | **ADR:** ADR-0014, ADR-0010, ADR-0017 | **TR-ID:** TR-ui-001  
> **Prioridad:** Sprint 2 | **Story:** presentation-hud-ui/102  
> **Estado:** HUD overlay (temporal durante diálogo) + panel persistente (chat log)

## Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│   ┌──────────────────────────────────────┐   │
│   │  NPC: Moni Graná Fert  (garnet)      │   │
│   │ ─────────────────────────────────     │   │
│   │ [Moni] That's Barry's lighter. He    │   │
│   │ lit my cigarette with it.            │   │
│   │                                      │   │
│   │ [Tú] How do you know it's his?      │   │
│   │                                      │   │
│   │ [Moni] I'd know it anywhere,        │   │
│   │ detective. He's the only one who    │   │
│   │ uses gold.                           │   │
│   │                                      │   │
│   │            ──  EVIDENCE ──           │   │
│   │   ⬜ ¿Agregar "Encendedor de        │   │
│   │     Moni" como evidencia?           │   │
│   │   [Sí]  [No]                        │   │
│   │                                      │   │
│   │ [Status] Presiona V para hablar     │   │
│   └──────────────────────────────────────┘   │
│                                              │
│   ┌──────────────────────────────────────┐   │
│   │ [Barry Peel] (yellow)  [Tú]         │   │
│   │ I signed mine         I think you   │   │
│   │ tonight.              did.          │   │
│   └──────────────────────────────────────┘   │
│           (HUD subtitles dual-channel)        │
└──────────────────────────────────────────────┘
```

## Dos Modos de Visualización

### Modo 1: HUD Subtitles (default)
- Subtítulos dual-channel en SubtitlePanel (ver hud.md)
- Visible durante diálogo activo
- Muestra la última línea de cada canal (NPC + player)
- Se desvanece 0.3s después de cada frase

### Modo 2: Chat Log (abierto con Estando en rango NPC)
- Panel más grande que cubre el tercio inferior de la pantalla
- Muestra historial completo de la conversación actual
- Scrollable con rueda del mouse
- Incluye prompts de evidencia (testimonios)

## Elementos del Chat Log

### Chat Log Panel
- **Posición:** Bottom-center, cubre ~30% de la pantalla
- **Fondo:** `#0F0F15` con borde `#D9A63C` 1px (noir)
- **Fuente:** Special Elite 12pt para mensajes, 10pt para metadatos
- **Scroll:** Rueda del mouse. Auto-scroll a lo nuevo por defecto

### Mensajes
- **NPC message:** `[Nombre]` en color identidad + texto en blanco
- **Player message:** `[Tú]` en `#87CEEB` + texto en blanco
- **Evidence prompt:** Línea separadora `─ EVIDENCE ─`, checkbox + texto, botones [Sí] [No]
- **Status bar:** Texto informativo en gris `#7A6A50`: "Presiona V para hablar", "Gajito está procesando...", etc.

### Evidence Prompt
- Aparece cuando el LLM detecta una línea clave en la respuesta del NPC
- Texto: `¿Agregar "[evidence_name]" como evidencia?`
- Botones: `[Sí]` (emite `add_testimony(evidence_id)`) / `[No]` (descarta)
- Auto-dismiss si no se responde en 10s (cuenta como No)

## Flujo de Diálogo

```
Jugador presiona E cerca de NPC
  → Sistema abre diálogo (si no está abierto)
  → Chat Log aparece
  → NPC muestra línea de apertura
  → HUD SubtitlePanel muestra misma línea

Jugador mantiene V → habla → suelta V
  → Transcripción aparece en PlayerSubtitle + Chat Log
  → "Gajito pensando..." en PTTIndicator
  → Respuesta del NPC llega
  → NPCSubtitle + Chat Log: typewriter del texto
  → Si detection de evidencia → Evidence prompt

Jugador presiona ESC (o se aleja del NPC)
  → Chat Log se cierra
  → Diálogo termina
  → HUD subtitles ocultos
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Dialogue started | InteractionSystem → DialoguePanel | npc_id |
| Evidence prompt | LLMClient → DialoguePanel | `{evidence_id, evidence_name}` |
| Evidence accepted | DialoguePanel → GameManager | evidence_id |
| Dialogue closed | DialoguePanel → InteractionSystem | — |
| Player message | VoiceManager → DialoguePanel | transcript String |
| NPC response | LLMClient → DialoguePanel | `{npc_id, text}` |

## Reglas de Visibilidad

- Chat Log visible solo durante diálogo activo (en rango de NPC + diálogo abierto)
- HUD Subtitles visible durante y brevemente después de cada intercambio
- Chat Log se cierra si el jugador se aleja >3m del NPC
- Evidence prompt visible por 10s máximo
- ESC cierra el diálogo

## Cursor

- **Chat Log cerrado:** `MOUSE_MODE_CAPTURED` (HUD no interactivo)
- **Chat Log abierto:** `MOUSE_MODE_VISIBLE` (para scroll y botones de evidencia)

## Accesibilidad

- Fuente Special Elite 12pt mínimo en chat log
- Colores de identidad en nombres NPC (GDD §8.4)
- Evidence prompt usa checkbox + texto + botones (no solo color)
- Chat log es scrolleable con teclado (PageUp/PageDown)

## Assets Necesarios

- Ya existe `game/scenes/ui/dialogue.tscn` y `game/scripts/ui/dialogue.gd` — refactorizar para usar art bible colors y nuevo layout
- Reemplazar hardcoded colors (lightblue/orange) por constantes de paleta
- Añadir: evidence prompt UI, scroll container, status bar
