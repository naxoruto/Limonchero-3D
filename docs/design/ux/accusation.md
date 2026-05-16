# UX Spec: Accusation Tree (Papolicia Dialogue)

> **GDD:** §8.3.3 | **ADR:** ADR-0014 | **TR-ID:** TR-ui-005  
> **Prioridad:** Sprint 4 | **Story:** presentation-hud-ui/108  
> **Estado:** Sistema overlay (diálogo scripteado con Commissioner Papolicia)

## Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│   ┌──────────────────────────────────────┐   │
│   │                                        │
│   │   Commissioner Papolicia                   │
│   │   ─────────────────────               │   │
│   │                                        │   │
│   │   "Alright detective. You've had      │   │
│   │   your time. Who did it, and what's   │   │
│   │   your evidence?"                      │   │
│   │                                        │   │
│   │   ──── PRESENTA TUS PRUEBAS ────      │   │
│   │                                        │   │
│   │   ☑ Acuerdo del Fideicomiso (F1)     │   │
│   │   ☑ Llave Maestra (F2)               │   │
│   │   ☐ Encendedor de Oro (F3)           │   │
│   │   ☐ Maleta de Moni (F4)              │   │
│   │   ☐ Carta Quemada (F5)               │   │
│   │                                        │   │
│   │   (Selecciona hasta 3 pruebas)       │   │
│   │                                        │   │
│   │   ──── ACUSACIÓN ────                 │   │
│   │                                        │   │
│   │   ¿Quién es el culpable?              │   │
│   │   [________________________]          │   │
│   │                                        │   │
│   │   ┌──────────────────────┐           │   │
│   │   │     ACUSAR          │           │   │
│   │   └──────────────────────┘           │   │
│   │                                        │   │
│   └──────────────────────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
```

## Elementos

### Diálogo de Papolicia
- **NPC:** Commissioner Papolicia (marrón tierra `#6B4423`)
- **Texto:** Diálogo scripteado (no LLM). Misma línea siempre.
- **Formato:** Typewriter 0.03s/car, nombre en color identidad, texto blanco

### Selección de Evidencias (Checkboxes)
- **Lista:** Todas las pistas con estado BUENA (las MALA/SIN_REVISAR aparecen grises, no seleccionables)
- **Máximo:** 3 selecciones (checkbox se desactiva al llegar a 3 si no se desmarca una)
- **Visual:** Checkbox cuadrado `#3D3020`, check `#D4A030`, label en `#E8D5A3`
- **Evidencias no disponibles:** Gris `#5A5048`, texto tachado, tooltip "Esta pista no es concluyente"

### Campo de Acusado
- **Label:** "¿Quién es el culpable?"
- **Input:** Texto libre, autocomplete con nombres de NPCs
- **Placeholder:** "Escribe el nombre del sospechoso..."
- **Validación:**
  - Vacío → botón "Acusar" desactivado
  - Texto no coincide con NPC conocido → botón activo pero advertencia "¿Estás seguro? No hay un sospechoso con ese nombre"
  - Texto coincide con "Barry" o "Barry Peel" → válido

### Botón Acusar
- **Estado activo:** Al menos 1 evidencia seleccionada + nombre de acusado no vacío
- **Estado inactivo:** Gris, texto secundario
- **Acción:** `GameManager.can_confess(accused)` → determina outcome

## Estados del Árbol

| Paso | Descripción | UI |
|------|-------------|-----|
| **1. Papolicia pregunta** | Línea de apertura | Diálogo de Papolicia + botón "Presentar caso" |
| **2. Seleccionar evidencias** | Jugador elige hasta 3 | Checkboxes con pistas BUENA |
| **3. Nombrar acusado** | Jugador escribe nombre | Campo de texto |
| **4. Confirmar** | Revisar selección | Resumen + botones "Acusar" / "Cancelar" |
| **5. Veredicto** | Papolicia evalúa | Transición a CaseResolution |

## Flujo

```
Jugador habla con Papolicia (E) estando en Zona 1
  → Diálogo scripteado inicia
  → Papolicia: línea de apertura

Jugador click "Presentar caso"
  → Mostrar checkboxes con evidencias BUENA
  → Jugador selecciona hasta 3
  → Jugador escribe nombre del acusado

Jugador click "Acusar"
  → Mostrar resumen: "Acusando a [name] con [n] pruebas. ¿Correcto?"
  → Botones: "Sí, acusar" / "Cancelar"

Jugador click "Sí, acusar"
  → GameManager.can_confess(accused_name)
  → Si true:
      → TransitionScene.play() (fade out)
      → CaseResolution.show(resolved=true)
  → Si false:
      → Papolicia: "That's not the right answer, detective. Try again."
      → Volver al paso 1 (sin penalización, intentos contados en telemetría)
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Accusation started | InteractionSystem → AccusationUI | — |
| Evidence selected | AccusationUI → — | selected_evidences (Array) |
| Accused named | AccusationUI → — | accused_name (String) |
| Accuse clicked | AccusationUI → GameManager | `{accused, evidences}` |
| Verdict received | GameManager → AccusationUI | `{correct: bool}` |
| Accusation closed | AccusationUI → SceneLoader | — |

## Reglas de Visibilidad

- Solo accesible en Zona 1 (Vestíbulo) hablando con Papolicia
- No se puede abrir pausa durante la acusación (Art Bible §2.4)
- No se puede abrir inventario durante la acusación
- Si el jugador se aleja de Papolicia → diálogo se cancela, vuelve al paso 1
- Intentos fallidos se cuentan en telemetría (`accusation_attempts` — ADR-0007)

## Cursor

- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Checkboxes:** Click para seleccionar/deseleccionar
- **Campo de texto:** Click para focus, teclado para escribir
- **Botón:** Click para acusar

## Accesibilidad

- Navegación por teclado: Tab entre elementos, Enter para seleccionar
- Evidencias tienen nombre + código (F1, F2...) para identificación no-cromática
- Máximo 3 selecciones evita errores de juicio
- Confirmación antes de acusar evita accidentes
- Feedback de Papolicia en caso incorrecto (no solo pantalla de fallo)

## Assets Necesarios

- Checkbox outline + check (SVG, 16×16px)
- Scrollbar para lista de evidencias (si hay más de 6)
- Texture de fondo (misma que diálogo noir, `#0F0F15`)
