# ADR-0008: Lógica de Puerta de Confesión — Condiciones para que Barry Confiese

## Estado
Propuesto

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Núcleo / Lógica de Juego |
| **Riesgo de Conocimiento** | BAJO — lógica pura GDScript; sin APIs post-corte |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 GDScript |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que todos los caminos de acusación (éxito, fallo por NPC equivocado, fallo por pruebas insuficientes) se prueban manualmente en una sesión completa |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager.is_confession_gate_open(), señal gate_opened()) |
| **Habilita** | Epic de acusación/final — el sistema de acusación no puede implementarse sin estas reglas |
| **Bloquea** | Ninguno |
| **Nota de Orden** | Implementar junto con AccusationSystem (Feature Layer) |

## Contexto

### Declaración del Problema
El juego tiene un único culpable hardcodeado: Barry Peel. El jugador puede acusar a cualquier NPC en cualquier momento desde el menú de acusación, pero Barry solo puede confesar si el jugador ha reunido pruebas suficientes. Se necesita definir exactamente qué condiciones abren la puerta de confesión, qué ocurre cuando se cumple, y qué ocurre cuando el jugador acusa sin pruebas.

### Restricciones
- Culpable único y hardcodeado: `barry`
- Las 3 pistas clave son F1, F2, F3 — cada una debe estar marcada como `"good"` en `GameManager.clues`
- F3 (`"lighter_barry"`) debe ser confirmada por Moni — sin esa confirmación, F3 no llega a estado `"good"`
- Acusar sin pruebas suficientes termina la partida con pantalla de fallo inmediato
- `accusation_attempts` se registra en telemetría independientemente del resultado

### Requisitos
- `is_confession_gate_open()` debe ser evaluable en cualquier momento desde cualquier módulo
- La acusación es un punto de no retorno — una vez acusado, no se puede cancelar
- Acusar al NPC equivocado termina la partida con fallo inmediato (sin retorno)
- Acusar a Barry sin la puerta abierta también termina con fallo inmediato (sin retorno)
- Solo acusar a Barry con la puerta abierta lleva a la confesión y resolución del caso

## Decisión

**La puerta de confesión se evalúa en `GameManager.is_confession_gate_open()`. La acusación es irreversible. Cualquier acusación inválida termina la partida en fallo inmediato. Solo Barry + puerta abierta produce la confesión y la señal `case_resolved`.**

### Lógica de evaluación

```gdscript
# res://scripts/foundation/game_manager.gd
const CONFESSION_CLUES := ["F1", "F2", "F3"]
const CULPRIT_ID := "barry"

func is_confession_gate_open() -> bool:
    for clue_id in CONFESSION_CLUES:
        if clues.get(clue_id, {}).get("state", "") != "good":
            return false
    return true
```

### Flujo de acusación completo

```
Jugador selecciona "Acusar" en el menú de acusación
  → AccusationSystem.accuse(npc_id)
      → GameManager.accusation_attempts += 1
      → GameManager.accused_npc_id = npc_id

  CASO A: npc_id != "barry"
      → Fallo inmediato
      → GameManager.case_resolved = false
      → emit_signal("case_failed", "wrong_accusation")
      → Pantalla de fallo: "Acusaste a la persona equivocada."

  CASO B: npc_id == "barry" AND NOT is_confession_gate_open()
      → Fallo inmediato
      → GameManager.case_resolved = false
      → emit_signal("case_failed", "insufficient_evidence")
      → Pantalla de fallo: "No tienes suficientes pruebas para acusar a Barry."

  CASO C: npc_id == "barry" AND is_confession_gate_open()
      → Puerta abierta — Barry confiesa
      → emit_signal("gate_opened")
      → [Secuencia de confesión — diálogo LLM especial con prompt de confesión]
      → GameManager.case_resolved = true
      → emit_signal("case_resolved")
      → GameManager.export_session_json()
      → Pantalla de cierre con session_id
```

### Diagrama de estados

```
[Investigando]
     │
     ├── accuse(wrong_npc) ──────────────────────────→ [FALLO: persona equivocada]
     │
     ├── accuse(barry) + gate CERRADA ───────────────→ [FALLO: sin pruebas]
     │
     └── accuse(barry) + gate ABIERTA ───────────────→ [gate_opened]
                                                              │
                                                        [Barry confiesa]
                                                              │
                                                       [case_resolved]
                                                              │
                                                      [Pantalla de cierre]
```

### Interfaces clave

```gdscript
# AccusationSystem (Feature Layer) — res://scripts/features/accusation_system.gd
func accuse(npc_id: String, presented_evidence: Array) -> void:
    var is_correct := (npc_id == GameManager.CULPRIT_ID and GameManager.is_confession_gate_open())
    GameManager.register_accusation(npc_id, presented_evidence, is_correct)
    if npc_id != GameManager.CULPRIT_ID:
        GameManager.emit_signal("case_failed", "wrong_accusation")
        return
    if not GameManager.is_confession_gate_open():
        GameManager.emit_signal("case_failed", "insufficient_evidence")
        return
    GameManager.emit_signal("gate_opened")
    # LLMClient usará prompt de confesión especial para esta llamada
```

### Señales nuevas requeridas en GameManager

```gdscript
# Agregar a res://scripts/foundation/game_manager.gd
signal case_failed(reason: String)   # "wrong_accusation" | "insufficient_evidence"
signal case_resolved()               # Barry confesó — caso cerrado
```

## Alternativas Consideradas

### Alternativa 1: Acusación fallida no termina la partida
- **Descripción:** Barry niega y el jugador puede seguir investigando; `accusation_attempts` se incrementa
- **Pros:** Más permisivo; el jugador aprende de sus errores dentro del juego
- **Contras:** Reduce tensión dramática; puede llevar a spam de acusaciones para "testear"
- **Razón de rechazo:** El GDD usa la acusación como punto de no retorno para mantener tensión. El fallo es parte de la experiencia educativa — las consecuencias importan.

### Alternativa 2: Sistema de pistas parcial (abrir puerta con F1+F2 sin F3)
- **Descripción:** Permitir acusación exitosa con solo 2 de 3 pistas
- **Pros:** Reduce bloqueo si el jugador no encuentra F3
- **Contras:** Elimina la necesidad de interrogar a Moni para confirmar F3; reduce la profundidad investigativa
- **Razón de rechazo:** F3 confirmada por Moni es el pivote narrativo clave del GDD. Sin ella, el giro de Moni como testigo clave pierde sentido.

## Consecuencias

### Positivas
- Acusación como momento de alta tensión — el jugador no puede "probar" sin consecuencias
- `is_confession_gate_open()` es determinista — fácil de probar y debuggear
- Los 3 caminos producen pantallas de cierre distintas con valor educativo diferente

### Negativas
- No hay "segunda oportunidad" — si el jugador acusa demasiado pronto, reinicia desde el menú principal
- `accusation_attempts` en telemetría será casi siempre 1 (acusan una sola vez por sesión)

### Riesgos
- **Riesgo:** Anti-stall L3 empuja al jugador a acusar antes de tener las 3 pistas. **Mitigación:** L3 da información sobre el culpable pero no reemplaza las pistas — el jugador aún necesita F1+F2+F3 en estado `"good"`.
- **Riesgo:** `clues["F3"]` nunca llega a `"good"` si el jugador no habla con Moni. **Mitigación:** Anti-stall L2 apunta explícitamente a interrogar a todos los NPCs; Gajito puede dar hints.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | `confesion_gate`: F1+F2+F3 BUENAS + Barry nombrado | `is_confession_gate_open()` evalúa exactamente estas condiciones |
| gdd_detective_noir_vr.md | Puerta de acusación — punto de no retorno | Toda acusación es irreversible; fallo termina la partida inmediatamente |

## Implicaciones de Rendimiento
- **CPU:** `is_confession_gate_open()` — 3 lookups en Dictionary; ~microsegundos
- **Memoria:** Sin impacto — constantes y condición simple
- **Tiempo de carga:** Sin impacto
- **Red:** Sin impacto

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- Acusar a Lola sin ninguna pista → pantalla de fallo "persona equivocada" dentro de 1 frame
- Acusar a Barry con solo F1 y F2 → pantalla de fallo "sin pruebas suficientes"
- Acusar a Barry con F1+F2+F3 todos en estado `"good"` → `gate_opened` → Barry confiesa → `case_resolved`
- `accusation_attempts` incrementa en los 3 casos
- `export_session_json()` se llama exactamente una vez al resolver o fallar

## Decisiones Relacionadas
- ADR-0001: GameManager — define `is_confession_gate_open()`, `gate_opened`, `case_resolved`
- ADR-0007: Telemetría — `accusation_attempts` y `case_resolved` son campos del JSON de sesión
