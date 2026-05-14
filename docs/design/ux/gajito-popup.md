# UX Spec: Gajito Popup

> **GDD:** §8.3.2 | **ADR:** ADR-0016 | **TR-ID:** TR-ui-004  
> **Prioridad:** Sprint 3 | **Story:** presentation-hud-ui/104  
> **Estado:** HUD overlay temporal (auto-dismiss)

## Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
│                              ┌──────────────┐│
│                              │ 🍋 Gajito   ││
│                              │ ─────────── ││
│                              │ "I are" no   ││
│                              │ existe. Con  ││
│                              │ primera      ││
│                              │ persona se   ││
│                              │ usa "I am".  ││
│                              └──────────────┘│
│   ┌────────────────────┐                     │
│   │ Gajito: Deberías   │                     │
│   │ preguntar...       │                     │
│   └────────────────────┘                     │
│                                              │
└──────────────────────────────────────────────┘
```

## Elementos

### Gajito Popup
- **Posición:** Esquina inferior-izquierda, ~3% desde bordes izquierdo e inferior
- **Ancho máximo:** 280px (~25% de pantalla 1080p)
- **Fondo:** `#7ABE30` (verde lima) a 85% opacidad, bordes rectos
- **Borde:** `#6A9E20` 1px
- **Header:** "Gajito" en bold, Special Elite 11pt, color `#1E1810`
- **Cuerpo:** Texto de corrección en español, Special Elite 10pt, color `#1E1810`
- **Icono:** 🍋 (limón de pica), 16×16px, a la izquierda del header

### Prioridad de Mensajes

| Prioridad | Tipo | Duración | Ejemplo |
|-----------|------|----------|---------|
| **high** | Error gramatical grave | 5s | "I are going" → "I am going" |
| **low** | Sugerencia de estilo | 3s | "Maybe try: 'Could you clarify...'" |
| **hint** | Pista contextual (anti-stall) | 4s | "El guardarropa podría tener algo..." |

## Estados

| Estado | Contenido | Duración | Comportamiento |
|--------|-----------|----------|----------------|
| **IDLE** | — | — | Oculto |
| **SHOWING** | Corrección + explicación | 5s (high) / 3s (low) | Fade in 0.2s, texto typewriter 0.02s/car |
| **DISMISSING** | Mismo contenido | 0.5s | Fade out |
| **QUEUED** | Esperando turno | Variable | Si otro popup está visible, encola |

### Reglas de Prioridad (queue)
1. Si no hay popup visible → mostrar inmediatamente
2. Si hay un popup de prioridad `low` y llega uno `high` → el `high` reemplaza (el `low` se descarta)
3. Si hay un popup `high` mostrándose y llega otro `high` → se muestra después (cola FIFO para same priority)
4. Máximo 3 mensajes encolados. El 4+ se descarta.

## Flujo

```
LLMClient recibe respuesta de /grammar endpoint
  → grammar_response_received(original, correction, explanation_es, severity)
  → Si severity == "high":
      → GajitoPopup.queue(correction, "high", 5.0)
  → Si severity == "low":
      → GajitoPopup.queue(suggestion, "low", 3.0)

GajitoPopup.show(message, severity, duration):
  → Fade in (0.2s)
  → Typewriter del texto (0.02s/car)
  → Esperar duration
  → Fade out (0.5s)
  → Mostrar siguiente en cola (si existe)
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Grammar response | LLMClient → GajitoPopup | `{correction, explanation_es, severity}` |
| Popup shown | GajitoPopup → HUDManager | — |
| Popup dismissed | GajitoPopup → HUDManager | — |
| Anti-stall hint | GameManager → GajitoPopup | `{level, hint_text}` |

## Reglas de Visibilidad

- Siempre visible cuando hay un mensaje activo (independiente del estado de pausa)
- Se oculta si el menú de pausa o acusación está abierto (no molestar durante decisiones críticas)
- No se muestra durante el diálogo de acusación (silencio de Gajito es narrativamente importante — Art Bible §2.4)
- Auto-dismiss por tiempo (no requiere input del jugador)

## Cursor

- **No interactivo:** El popup es solo informativo, no tiene botones
- Cursor no cambia al pasar sobre el popup

## Accesibilidad

- Texto oscuro (`#1E1810`) sobre fondo verde claro (`#7ABE30`) → ratio > 4.5:1
- Respaldo de forma: el icono de limón + "Gajito" header identifica la fuente incluso sin color
- Duración suficiente para lectura (~15 palabras en 5s = lectura tranquila)
- Si el jugador no alcanza a leer, el historial queda en el chat log de Gajito (accesible desde notebook)

## Assets Necesarios

- Icono de limón de pica (🍋 o SVG simple, 16×16px, verde)
- Fondo semi-transparente verde lima (shader o textura 1×1px)
