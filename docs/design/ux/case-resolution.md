# UX Spec: Case Resolution

> **GDD:** §8.3.3 | **ADR:** ADR-0008, ADR-0017 | **TR-ID:** TR-ui-008  
> **Prioridad:** Sprint 4 | **Story:** presentation-hud-ui/109  
> **Estado:** Pantalla de cierre (post-acusación)

## Layout (Caso Resuelto)

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│               ┌───────────┐                  │
│               │           │                  │
│               │   BUENA   │                  │
│               │   (sello) │                  │
│               │           │                  │
│               └───────────┘                  │
│                                              │
│          C A S O   R E S U E L T O          │
│                                              │
│   ────────────────────────────────────────   │
│                                              │
│   Has arrestado a [Barry Peel] por el       │
│   asesinato de Cornelius "Corn" Maize.      │
│                                              │
│   Pruebas presentadas:                       │
│   • Acuerdo del Fideicomiso (F1)            │
│   • Llave Maestra (F2)                      │
│   • Encendedor de Oro (F3)                  │
│                                              │
│   ────────────────────────────────────────   │
│                                              │
│   ID de sesión: a1b2c3d4-e5f6-...           │
│                                              │
│   ┌──────────────────────────────┐          │
│   │   Volver al menú principal  │          │
│   └──────────────────────────────┘          │
│                                              │
└──────────────────────────────────────────────┘
```

## Layout (Caso Fallido)

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│               ┌───────────┐                  │
│               │  ┌─┐      │                  │
│               │  │X│      │                  │
│               │  └─┘      │                  │
│               │   MALA    │                  │
│               │  (sello)  │                  │
│               └───────────┘                  │
│                                              │
│         C A S O   F A L L I D O             │
│                                              │
│   ────────────────────────────────────────   │
│                                              │
│   [Nombre del acusado] no es el culpable.   │
│                                              │
│   El verdadero culpable es Barry Peel,      │
│   quien confesó haber disparado a           │
│   Cornelius con el arma del club.           │
│                                              │
│   ────────────────────────────────────────   │
│                                              │
│   ID de sesión: a1b2c3d4-e5f6-...           │
│                                              │
│   ┌──────────────────────────────┐          │
│   │   Volver al menú principal  │          │
│   └──────────────────────────────┘          │
│                                              │
└──────────────────────────────────────────────┘
```

## Elementos

### Sello BUENA (Caso Resuelto)
- **Forma:** Círculo completo con borde grueso
- **Color:** `#2A5A20` (verde botella, desaturado)
- **Texto:** "BUENA" en caps, tipografía de sello de caucho
- **Tamaño:** ~80×80px centrado

### Sello MALA (Caso Fallido)
- **Forma:** Círculo con X interior
- **Color:** `#6A1520` (rojo sello)
- **Texto:** "MALA" en caps
- **Tamaño:** ~80×80px centrado

### Texto de Resolución
- **Header:** "CASO RESUELTO" / "CASO FALLIDO" en Special Elite 24pt, `#E8D5A3`
- **Cuerpo:** Descripción del resultado en Special Elite 14pt, `#E8D5A3`
  - Caso resuelto: nombre del culpable + evidencias presentadas
  - Caso fallido: nombre del acusado incorrecto + revelación del verdadero culpable
- **Fondo:** Panel `#0D0D0D` centrado, 50% de ancho

### Session ID
- **Texto:** "ID de sesión: [uuid]" en Special Elite 10pt, `#7A6A50`
- **Propósito:** Referencia para exportación JSON y telemetría

### Botón
- **Label:** "Volver al menú principal"
- **Estilo:** Borde `#D4A030` 1px, texto `#E8D5A3`, hover resalta
- **Acción:** SceneLoader.load("main_menu")

## Estados

| Estado | Sello | Header | Cuerpo | Botón |
|--------|-------|--------|--------|-------|
| **Correcto** | BUENA (círculo verde) | "CASO RESUELTO" | Culpable + evidencias | "Volver" |
| **Incorrecto** | MALA (círculo rojo + X) | "CASO FALLIDO" | Acusado incorrecto + verdad | "Volver" |

## Flujo

```
GameManager.can_confess(accused) retorna:
  → true:
    → GameManager.log_event("case_resolved", {accused, evidences})
    → GameManager.export_session_json()
    → CaseResolution.show(resolved=true, accused, evidences)
  → false:
    → GameManager.log_event("case_failed", {accused, evidences})
    → Exportación
    → CaseResolution.show(resolved=false, accused, evidences)

Jugador lee resolución
Jugador click "Volver al menú principal"
  → SceneLoader.load("main_menu")
```

## Señales

| Evento | Emisor → Receptor | Dato |
|--------|------------------|------|
| Case resolved | GameManager → CaseResolution | `{resolved, accused, evidences}` |
| Back to menu | CaseResolution → SceneLoader | "main_menu" path |

## Reglas de Visibilidad

- Pantalla final del juego — no hay gameplay después de esto
- No se puede abrir pausa
- No se puede volver atrás (no hay "reintentar")
- La música de jazz se corta al iniciar la secuencia (silencio excepto lluvia — Art Bible §2.4)
- Gajito no habla durante esta pantalla (Art Bible §2.4)

## Cursor

- **Modo:** `Input.MOUSE_MODE_VISIBLE`
- **Botón:** Hover resalta borde

## Accesibilidad

- Sellos BUENA/MALA tienen forma + color (daltonismo-safe, Art Bible §4.5)
- Texto contrastado: `#E8D5A3` sobre `#0D0D0D` (ratio > 13:1)
- Session ID en gris bajo (no roba atención) pero seleccionable con Ctrl+C
- Botón grande (mín 44px altura)

## Assets Necesarios

- Sello BUENA (SVG, círculo verde `#2A5A20`, texto "BUENA")
- Sello MALA (SVG, círculo rojo `#6A1520` con X, texto "MALA")
- Fondo de pantalla (negro o versión oscura del club)
