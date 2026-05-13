# ADR-0001: GameManager como Singleton Autoload — Patrón de Estado Canónico

## Estado
Aceptado

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Núcleo / Scripting |
| **Riesgo de Conocimiento** | BAJO — Autoload es un patrón estable desde Godot 3.x |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 (sin biblioteca engine-reference configurada) |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que `FileAccess.open()` con `user://` funciona en build exportado Windows/Linux |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | Ninguna |
| **Habilita** | ADR-0007 (telemetría de sesión), ADR-0008 (lógica puerta de confesión) |
| **Bloquea** | Todos los sistemas de Características y Núcleo — no pueden implementarse sin estado canónico |
| **Nota de Orden** | Debe ser el primer ADR implementado. GameManager.gd debe existir antes de cualquier otra escena |

## Contexto

### Declaración del Problema
El juego necesita un estado centralizado accesible desde múltiples módulos independientes: pistas recolectadas, flags de evidencia (F1/F2/F3), puerta de confesión, nivel de inglés seleccionado, ID de sesión, y datos de telemetría para pruebas de usuario. Sin un punto de verdad único, cada módulo mantendría su propia copia del estado, generando inconsistencias y duplicación.

### Restricciones
- Godot 4.6 GDScript (sin C#)
- Sesión única sin guardado persistente de progreso
- El estado de telemetría debe sobrevivir hasta el cierre del juego (incluyendo cierre inesperado con `SceneTree.quit()`)
- Equipo de 4 personas — el patrón debe ser simple de entender y usar

### Requisitos
- Accesible desde cualquier nodo sin pasar referencias manualmente
- Debe garantizar una sola instancia durante toda la ejecución
- Debe poder exportar JSON al disco al finalizar la sesión
- Debe emitir señales cuando el estado cambia (para desacoplar módulos de presentación)

## Decisión

**GameManager se implementa como Autoload singleton en Godot 4.6.**

Se registra en `Project Settings → Autoload` como `GameManager` apuntando a `res://scripts/foundation/game_manager.gd`. Esto hace que el nodo esté disponible globalmente en toda la escena como `GameManager.método()` sin importaciones ni referencias adicionales.

GameManager es la **única fuente de verdad** para el estado del juego. Ningún otro módulo almacena estado de juego duplicado. Toda lectura y escritura de estado ocurre exclusivamente a través de los métodos públicos de GameManager.

### Diagrama de Arquitectura

```
Autoload (Project Settings)
  └── GameManager (res://scripts/foundation/game_manager.gd)
        ├── Estado: pistas, flags, telemetría, english_level, session_id
        ├── Métodos públicos → únicos puntos de escritura de estado
        └── Señales → mecanismo de notificación (sin acoplamiento directo a UI/Feature)

Cualquier módulo (Feature, Core, Presentation)
  └── GameManager.add_clue("F1")       ← escritura siempre por método
  └── GameManager.clue_added.connect() ← lectura reactiva por señal
  └── GameManager.get_clue_state("F1") ← lectura directa cuando necesario
```

### Interfaces Clave

```gdscript
# res://scripts/foundation/game_manager.gd
extends Node

# ── Estado de sesión ──────────────────────────────────────
var session_id: String = ""
var english_level: String = "intermediate"  # "beginner"|"intermediate"|"advanced"
var session_start_time: float = 0.0

# ── Estado de evidencias ──────────────────────────────────
var clues: Dictionary = {}
# Estructura: { "F1": { "state": "good", "timestamp": 142.3 }, ... }  # state: "good"|"not_good"|"unchecked"

# ── Telemetría ────────────────────────────────────────────
var npcs_interrogated: Dictionary = {}
var accusation_attempts: Array = []
var grammar_errors_count: int = 0
var anti_stall_triggers: Dictionary = {"L1": 0, "L2": 0, "L3": 0}

# ── Señales ───────────────────────────────────────────────
signal clue_added(clue_id: String)
signal clue_state_changed(clue_id: String, state: String)
signal gate_opened()

# ── API pública ───────────────────────────────────────────
func initialize_session(p_session_id: String, p_english_level: String) -> void
func add_clue(clue_id: String) -> void
func set_clue_state(clue_id: String, state: String) -> void  # state: "good"|"not_good"|"unchecked"
func get_clue_state(clue_id: String) -> String  # returns "good"|"not_good"|"unchecked"|""
func is_confession_gate_open() -> bool
func register_interrogation(npc_id: String) -> void
func register_grammar_error() -> void
func register_accusation(suspect: String, evidence: Array, correct: bool) -> void
func export_session_json() -> void
```

## Alternativas Consideradas

### Alternativa 1: Estado pasado como referencia entre nodos
- **Descripción:** El nodo raíz de la escena mantiene el estado y lo pasa a los hijos vía parámetros o `get_node()`
- **Pros:** Sin singleton global; más testeable en aislamiento
- **Contras:** Requiere pasar referencias por toda la jerarquía; imposible acceder desde módulos desacoplados (UI, Anti-Estancamiento); frágil cuando cambia la jerarquía de escenas
- **Razón de rechazo:** El juego tiene múltiples módulos en distintas ramas del árbol de escena que necesitan el mismo estado. Pasar referencias sería impracticable.

### Alternativa 2: Resource global compartido (GameState.tres)
- **Descripción:** Un recurso Godot (`Resource`) con el estado del juego, cargado por todos los módulos que lo necesitan
- **Pros:** Sin singleton; serializable automáticamente con Godot
- **Contras:** Los `Resource` en Godot 4.6 no emiten señales de forma nativa; requeriría un bus de señales separado; más complejo para telemetría dinámica
- **Razón de rechazo:** La combinación de estado + señales + exportación JSON se implementa más limpiamente en un Node (Autoload) que en un Resource.

## Consecuencias

### Positivas
- API global simple: `GameManager.add_clue("F1")` desde cualquier script sin importaciones
- Señales desacoplan completamente la UI y los módulos de presentación del estado
- Garantía de instancia única por diseño del motor
- Telemetría centralizada: un solo lugar para registrar todos los eventos de sesión

### Negativas
- Estado global — más difícil de testear en aislamiento (sin mock fácil en GDScript)
- Cualquier módulo puede llamar métodos de GameManager — requiere disciplina de equipo para no saltarse la API pública

### Riesgos
- **Riesgo:** Un módulo escribe directamente en `GameManager.clues` sin usar `add_clue()`. **Mitigación:** Documentar explícitamente en CLAUDE.md y en revisiones de código que `clues` es privado por convención. Considerar prefijo `_clues` en implementación.
- **Riesgo:** `export_session_json()` no se llama si el juego crashea inesperadamente. **Mitigación:** Conectar también a `get_tree().connect("tree_exiting", ...)` además del flujo normal de `SceneTree.quit()`.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-estado-001: GameManager autoload con estado de pistas, progreso, flags | Implementación directa como Autoload singleton |
| gdd_detective_noir_vr.md | TR-telemetria-001: Registro de eventos con marca de tiempo | GameManager posee todas las variables de telemetría y los métodos de registro |
| gdd_detective_noir_vr.md | TR-telemetria-002: Export JSON al terminar o al salir | `export_session_json()` conectado a `case_resolved` y `tree_exiting` |
| gdd_detective_noir_vr.md | TR-telemetria-003: Campos de sesión completos | Todas las variables definidas en la interfaz pública de este ADR |

## Implicaciones de Rendimiento
- **CPU:** Insignificante — el estado es un Dictionary y variables primitivas; no hay cálculo por fotograma
- **Memoria:** < 1 KB para el estado típico de una sesión (6 pistas, 5 NPCs, ~10 intentos de acusación)
- **Tiempo de carga:** Cero — Autoload inicializa antes de la primera escena, sin costo perceptible
- **Red:** No aplica

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- `GameManager` accesible desde cualquier script sin `preload` ni `get_node()`
- `add_clue("F1")` emite señal `clue_added("F1")` correctamente
- `is_confession_gate_open()` retorna `false` con F1+F2 BUENAS, `true` con F1+F2+F3 BUENAS + Barry nombrado
- `export_session_json()` escribe archivo JSON válido en `user://` tanto en editor como en build exportado
- Al cerrar el juego con Alt+F4 (sin pasar por menú), el JSON se escribe igualmente

## Decisiones Relacionadas
- Arquitectura maestra: `docs/architecture/architecture.md`
- ADR-0007 (pendiente): Telemetría de sesión — detalla los campos y formato JSON
- ADR-0008 (pendiente): Lógica de puerta de confesión — implementación de `is_confession_gate_open()`
