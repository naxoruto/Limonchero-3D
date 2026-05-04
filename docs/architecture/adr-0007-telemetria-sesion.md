# ADR-0007: Telemetría de Sesión — Exportación JSON para Análisis Académico

## Estado
Aceptado

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Núcleo / Persistencia |
| **Riesgo de Conocimiento** | BAJO — `FileAccess`, `JSON`, `Time` son APIs estables desde Godot 4.0 |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 FileAccess y JSON APIs |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que `user://` resuelve correctamente en Windows (AppData/Roaming) y que el archivo se crea sin permisos especiales |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager.export_session_json() ya definido como método público) |
| **Habilita** | Análisis post-sesión para informe académico |
| **Bloquea** | Ninguno |
| **Nota de Orden** | Implementar junto con GameManager — export_session_json() es parte de ADR-0001 |

## Contexto

### Declaración del Problema
El proyecto es un trabajo académico que requiere análisis de uso durante las pruebas de usuario. Se necesita capturar datos de sesión (evidencias recogidas, intentos de acusación, duración, nivel de inglés elegido, errores gramaticales detectados) sin requerir internet ni servidores externos. El investigador recopilará los archivos JSON al finalizar cada sesión y los cruzará con un cuestionario Google Forms usando el `session_id` como clave de vinculación.

### Restricciones
- Sin servidor de telemetría — todo local (proyecto académico, sin infraestructura)
- El participante no debe saber que se está grabando telemetría (experiencia transparente)
- El JSON debe ser legible por el equipo sin herramientas especiales
- El archivo debe persistir aunque el juego crashee o se cierre abruptamente
- `session_id` debe ser visible al participante solo en la pantalla final (para vincular con Google Forms)

### Requisitos
- Exportar un archivo JSON por sesión al directorio `user://`
- Capturar campos definidos en el GDD para análisis académico
- Disparar exportación automáticamente al resolver el caso o cerrar el juego
- Mostrar `session_id` en pantalla de cierre para vincular con Google Forms
- Actualizaciones incrementales durante la sesión para sobrevivir crashes

## Decisión

**GameManager acumula telemetría durante toda la sesión en variables internas. Al dispararse `tree_exiting` o `case_resolved`, llama `export_session_json()` que escribe un archivo JSON en `user://sesion_{session_id}_{timestamp}.json`.**

### Estructura del JSON exportado

```json
{
  "session_id": "abc123",
  "timestamp_start": "2026-05-01T14:30:00",
  "timestamp_end": "2026-05-01T14:58:22",
  "duration_seconds": 1702,
  "english_level": "intermediate",
  "completed": true,
  "correct_accusation": true,
  "accusation_attempts": [
    {"suspect": "moni", "evidence": ["F3"], "correct": false, "timestamp": 601.2},
    {"suspect": "barry", "evidence": ["F1", "F2", "F3"], "correct": true, "timestamp": 1702.0}
  ],
  "clues": {
    "F1": {"state": "good", "timestamp": 142.3},
    "F2": {"state": "good", "timestamp": 380.1},
    "F3": {"state": "good", "timestamp": 511.7},
    "F4": {"state": "not_good", "timestamp": 290.5},
    "F5": {"state": "unchecked", "timestamp": 0.0}
  },
  "npcs_interrogated": {
    "barry": 5,
    "moni": 3,
    "lola": 2,
    "gerry": 1,
    "spud": 1
  },
  "grammar_errors_count": 4,
  "anti_stall_triggers": {
    "L1": 1,
    "L2": 0,
    "L3": 0
  }
}
```

### Campos y origen

| Campo | Origen | Tipo |
|-------|--------|------|
| `session_id` | `GameManager._generate_session_id()` — 6 chars alfanuméricos | String |
| `timestamp_start` | `Time.get_datetime_string_from_system()` en `initialize_session()` | String ISO8601 |
| `timestamp_end` | `Time.get_datetime_string_from_system()` en `export_session_json()` | String ISO8601 |
| `duration_seconds` | diferencia entre timestamps | int |
| `english_level` | `GameManager.english_level` | String |
| `completed` | `GameManager.case_resolved OR quit reached` | bool |
| `correct_accusation` | `GameManager.correct_accusation` — true si Barry acusado con gate abierta | bool |
| `accusation_attempts` | `GameManager.accusation_attempts` — Array; cada entrada por `register_accusation()` | Array |
| `clues` | `GameManager.clues` — dict clue_id → `{state, timestamp}` | Dictionary |
| `npcs_interrogated` | `GameManager.npcs_interrogated` | Dictionary |
| `grammar_errors_count` | `GameManager.grammar_errors_count` — incrementado por `register_grammar_error()` | int |
| `anti_stall_triggers` | `GameManager.anti_stall_triggers` — dict L1/L2/L3 | Dictionary |

### Implementación en GameManager

```gdscript
# res://scripts/foundation/game_manager.gd
var session_id: String = ""
var _timestamp_start: String = ""
var _session_exported: bool = false
var completed: bool = false
var correct_accusation: bool = false
var accusation_attempts: Array = []   # Array[{suspect, evidence, correct, timestamp}]
var grammar_errors_count: int = 0
var npcs_interrogated: Dictionary = {}
var anti_stall_triggers: Dictionary = {"L1": 0, "L2": 0, "L3": 0}

func initialize_session() -> void:
    session_id = _generate_session_id()
    _timestamp_start = Time.get_datetime_string_from_system()
    _session_exported = false
    # ... resto de init

func _generate_session_id() -> String:
    var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
    var result := ""
    for i in 6:
        result += chars[randi() % chars.length()]
    return result

func register_accusation(suspect: String, evidence: Array, correct: bool) -> void:
    accusation_attempts.append({
        "suspect": suspect,
        "evidence": evidence,
        "correct": correct,
        "timestamp": Time.get_unix_time_from_system() - _session_start_unix
    })
    if correct:
        correct_accusation = true
        completed = true

func export_session_json() -> void:
    if _session_exported:
        return
    _session_exported = true
    var ts_end := Time.get_datetime_string_from_system()
    var ts_start_unix := Time.get_unix_time_from_datetime_string(_timestamp_start)
    var ts_end_unix := Time.get_unix_time_from_datetime_string(ts_end)
    var data := {
        "session_id": session_id,
        "timestamp_start": _timestamp_start,
        "timestamp_end": ts_end,
        "duration_seconds": int(ts_end_unix - ts_start_unix),
        "english_level": english_level,
        "completed": completed,
        "correct_accusation": correct_accusation,
        "accusation_attempts": accusation_attempts,
        "clues": clues,
        "npcs_interrogated": npcs_interrogated,
        "grammar_errors_count": grammar_errors_count,
        "anti_stall_triggers": anti_stall_triggers,
    }
    var filename := "user://sesion_%s_%s.json" % [session_id, ts_end.replace(":", "-")]
    var file := FileAccess.open(filename, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func _ready() -> void:
    get_tree().connect("tree_exiting", export_session_json)
```

### Pantalla de cierre — mostrar session_id

```gdscript
# res://scripts/presentation/end_screen.gd
func _ready() -> void:
    $SessionLabel.text = "ID de sesión: %s" % GameManager.session_id
    $InstructionLabel.text = "Anota este código en el formulario de evaluación."
```

### Vinculación con Google Forms

El formulario incluye una pregunta: **"¿Cuál fue tu ID de sesión?"** (campo de texto corto). El equipo cruza la respuesta del formulario con el archivo `sesion_{id}_*.json` recogido del PC al finalizar la prueba. Sin envío de red — cero dependencia de internet.

## Alternativas Consideradas

### Alternativa 1: Exportación incremental (write on each event)
- **Descripción:** Escribir el archivo JSON completo a disco cada vez que cambia un campo
- **Pros:** Sobrevive crashes sin perder datos
- **Contras:** I/O frecuente en el hilo principal; complejidad adicional
- **Razón de rechazo:** Para sesiones de ~30 min con ~20 eventos, la pérdida de datos en crash es mínima. El I/O de un archivo < 1 KB al cerrar el juego es despreciable.

### Alternativa 2: POST automático a Google Forms
- **Descripción:** El juego envía el JSON vía HTTP directamente al endpoint de Google Forms
- **Pros:** Recopilación automática; sin gestión manual de archivos
- **Contras:** Requiere internet; Google Forms no tiene API pública para escritura; complejidad de CORS y autenticación
- **Razón de rechazo:** Las pruebas de usuario son en sala controlada — recogida manual es más simple y fiable.

### Alternativa 3: Base de datos SQLite local
- **Descripción:** Usar una base de datos SQLite para almacenar múltiples sesiones
- **Pros:** Consultas fáciles; múltiples sesiones en un solo archivo
- **Contras:** Requiere plugin SQLite para Godot 4; complejidad innecesaria
- **Razón de rechazo:** JSON plano es suficiente para ~10 participantes; SQLite es sobrediseño.

## Consecuencias

### Positivas
- Cero dependencia de red — funciona en cualquier sala sin internet
- JSON legible directamente con cualquier editor o Python/Excel
- `session_id` de 6 caracteres es fácil de anotar y memorizar
- El investigador puede analizar datos con un script Python simple

### Negativas
- Recogida manual de archivos al final de cada sesión (no automatizada)
- Si el PC de prueba no es el del equipo, se necesita un pendrive o acceso remoto para exportar los archivos

### Riesgos
- **Riesgo:** `export_session_json()` llamado dos veces (tree_exiting + case_resolved). **Mitigación:** Flag `_session_exported: bool` — segunda llamada retorna inmediatamente.
- **Riesgo:** `user://` no tiene permisos de escritura en Windows. **Mitigación:** Verificar en `_ready()` de GameManager que `FileAccess.open("user://test.tmp", FileAccess.WRITE)` no retorna null; si falla, loggear error.
- **Riesgo:** Participante cierra el juego antes de ver el session_id. **Mitigación:** El archivo ya fue escrito por `tree_exiting`; el investigador puede leer el session_id del nombre del archivo.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-telemetria-001: Exportar JSON de sesión para análisis académico | export_session_json() al cerrar o resolver caso |
| gdd_detective_noir_vr.md | TR-telemetria-002: session_id visible para vincular con Google Forms | Mostrado en pantalla de cierre; incluido en nombre del archivo |

## Implicaciones de Rendimiento
- **CPU:** Serialización JSON de < 1 KB — ~1ms al cierre; impacto nulo
- **Memoria:** Variables de telemetría en GameManager — < 10 KB total
- **Tiempo de carga:** Sin impacto
- **Red:** Sin uso de red

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- Al cerrar el juego, aparece un archivo `user://sesion_*.json` con todos los campos
- El `session_id` aparece en la pantalla de cierre del juego
- Si el caso se resuelve y luego se cierra el juego, el JSON se exporta solo una vez
- El archivo JSON es válido (parseable por Python `json.load()`)
- `duration_seconds` refleja correctamente la duración de la sesión

## Decisiones Relacionadas
- ADR-0001: GameManager — `export_session_json()` e `initialize_session()` definidos ahí
- ADR-0006: Nivel de inglés — `english_level` es campo obligatorio en el JSON
- ADR-0008: Puerta de confesión — `correct_accusation` y `completed` se activan cuando Barry confiesa
