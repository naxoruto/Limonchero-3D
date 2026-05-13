# ADR-0011: Anti-Stall System

## Estado
Propuesto

## Fecha
2026-05-01

## Compatibilidad con Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | Core / Game State |
| **Riesgo de Conocimiento** | BAJO — API de Timer node estable desde Godot 4.0 |
| **Referencias Consultadas** | ADR-0001 (GameManager/clue_added signal), ADR-0007 (anti_stall_triggers telemetry), ADR-0009 (GajitoModule) |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | Comportamiento de reset en modo one-shot del Timer; confirmar que `clue_added` se emite antes de que el timer pueda re-armarse |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager Propuesto — provee señal `clue_added` y dict `anti_stall_triggers`) |
| **Habilita** | ADR-0014 Módulo de Diálogo NPC (punto de integración de pistas de Gajito) |
| **Bloquea** | Ninguno |
| **Nota de Orden** | GameManager debe inicializar `_stall_timer` dentro de `initialize_session()` — antes de que se pueda agregar cualquier pista |

---

## Contexto

### Problema
No existe sistema que reaccione cuando el jugador deja de recolectar evidencia. Sin intervención, puede quedarse indefinidamente en un NPC o zona sin salida. El GDD especifica un sistema de pistas escalonado de tres niveles (L1/L2/L3) entregadas por Gajito para guiar al jugador de vuelta a la cadena de evidencia sin spoilear la solución.

### Restricciones
- Un solo nivel, una sola sesión — sin pause/resume. El ciclo de vida del timer está acotado a la sesión.
- Gajito ya existe como asistente visible al jugador; las pistas deben fluir a través de él para consistencia de UX.
- El dict `anti_stall_triggers` ya está definido en el esquema de telemetría ADR-0007 — debe incrementarse en cada disparo.
- GameManager es el único dueño del estado de sesión (ADR-0001) — el estado del timer vive allí.
- Los textos de pista están en español (Gajito habla español; idioma de UI = español).

### Requisitos
- Disparar pista L1 tras 4 min sin `clue_added`
- Disparar pista L2 a los 5 min de idle acumulado (1 min después de L1)
- Disparar pista L3 a los 7 min de idle acumulado (2 min después de L2)
- Resetear el reloj de idle en cada emisión de `clue_added`; resetear el nivel de stall a 0
- Tras disparar L3, no se emiten más pistas automáticas
- Cada disparo incrementa `GameManager.anti_stall_triggers["L1"|"L2"|"L3"]`
- El texto de pista debe ser contextualmente apropiado y sin spoiler (L1/L2) o casi-spoiler (L3)

---

## Decisión

GameManager posee el timer anti-stall y el contador de nivel de stall. Se agrega un único nodo `Timer` de Godot (modo one-shot) como hijo de GameManager en `initialize_session()`. Al expirar, emite `anti_stall_triggered(level: String)`, incrementa la telemetría y se rearma con el siguiente intervalo. Al recibir `clue_added`, el timer se resetea al umbral L1 y `_stall_level` vuelve a 0.

GajitoModule se conecta a `GameManager.anti_stall_triggered` y muestra un texto de pista predefinido en español para ese nivel en su overlay de pop-up existente.

### Tabla de Umbrales

| Nivel | Segundos idle desde última pista | Idle acumulado |
|-------|-----------------------------|-----------------|
| L1    | 240 s (4 min)               | 4 min           |
| L2    | 60 s tras L1                | 5 min           |
| L3    | 120 s tras L2               | 7 min           |
| Stop  | Sin más disparos            | —               |

### Diagrama de Arquitectura

```
GameManager
  ├── _stall_timer: Timer (one-shot)
  ├── _stall_level: int  # 0=armed, 1=L1_fired, 2=L2_fired, 3=L3_fired
  │
  ├── initialize_session() ──► create _stall_timer, start with STALL_THRESHOLDS[0]=240s
  │
  ├── add_clue(id) emits clue_added
  │     └── _on_clue_added() ──► _reset_stall_timer()
  │
  └── _on_stall_timer_timeout()
        ├── _stall_level += 1
        ├── emit anti_stall_triggered("L{_stall_level}")
        ├── anti_stall_triggers["L{_stall_level}"] += 1
        └── if _stall_level < 3 ──► _stall_timer.start(STALL_THRESHOLDS[_stall_level])

GajitoModule (autoload)
  └── GameManager.anti_stall_triggered.connect(_on_stall_hint)
        └── _on_stall_hint(level) ──► show_popup(HINT_TEXTS[level])
```

### Interfaces Clave

```gdscript
# ── GameManager additions ─────────────────────────────────────────────────────

# Constants
const STALL_THRESHOLDS: Array[float] = [240.0, 60.0, 120.0]  # L1, then +L2 delta, then +L3 delta

# New signal
signal anti_stall_triggered(level: String)  # "L1" | "L2" | "L3"

# New private state (initialized in initialize_session)
var _stall_timer: Timer
var _stall_level: int = 0  # 0=armed, 1..3=levels fired

func _reset_stall_timer() -> void:
    _stall_level = 0
    _stall_timer.stop()
    _stall_timer.start(STALL_THRESHOLDS[0])

func _on_stall_timer_timeout() -> void:
    _stall_level += 1
    var level_key := "L%d" % _stall_level
    anti_stall_triggers[level_key] += 1
    anti_stall_triggered.emit(level_key)
    if _stall_level < 3:
        _stall_timer.start(STALL_THRESHOLDS[_stall_level])

# initialize_session() must also start _stall_timer after session init
# add_clue() must call _reset_stall_timer() after emitting clue_added

# ── GajitoModule additions ────────────────────────────────────────────────────

const HINT_TEXTS: Dictionary = {
    "L1": "Limonchero, ¿has revisado todos los rincones del local? Hay más pistas esperándote.",
    "L2": "Quizás vale la pena hablar con alguien que aún no hayas interrogado del todo...",
    "L3": "El cenicero junto a la barra tiene algo interesante. Y no olvides el guardarropa."
}

func _on_stall_hint(level: String) -> void:
    show_popup(HINT_TEXTS[level])
```

---

## Alternativas Consideradas

### Alternativa A: AntiStallManager Autoload Dedicado
- **Descripción**: Singleton separado posee timers y lógica de pistas; se conecta a señales de GameManager externamente.
- **Pros**: Completamente desacoplado; fácil de deshabilitar anti-stall en tests.
- **Cons**: Agrega un tercer autoload Foundation; ADR-0001 ya centraliza estado de sesión en GameManager. Un singleton extra viola el patrón sin beneficio suficiente.
- **Razón de Rechazo**: Complejidad no justificada para un timer de tres niveles. GameManager ya posee el dict `anti_stall_triggers`.

### Alternativa B: Timer en Escena de Nivel
- **Descripción**: Timer anti-stall vive en `el_agave_y_la_luna.tscn`; resetea en señal de pista.
- **Pros**: Scoped al nivel, auto-liberado con la escena.
- **Cons**: La escritura de telemetría (`anti_stall_triggers`) requeriría una llamada cross-layer hacia GameManager, violando reglas de capas de ADR-0005. El estado de sesión quedaría dividido entre dos dueños.
- **Razón de Rechazo**: Rompe regla de ownership de estado de ADR-0001 y regla de capas de ADR-0005.

---

## Consecuencias

### Positivas
- Única fuente de verdad: timer y stall-level viven junto al resto del estado de sesión en GameManager.
- Integración de telemetría trivial — dict ya existe en esquema ADR-0007.
- Conexión de Gajito sigue patrón de señales existente (ADR-0005) — sin nuevo acoplamiento cross-layer.
- Reset de timer en `clue_added` es una llamada interna de una línea.

### Negativas
- GameManager crece más. Aceptado — ADR-0001 lo estableció como hub de estado de sesión.
- Textos de pistas son strings hardcodeados. Aceptable para juego académico de un solo nivel; no se necesita pipeline de localización.

### Riesgos
- **Riesgo**: El jugador recoge una pista durante la ventana de 1 frame entre `clue_added` y `_reset_stall_timer()` — el timer dispara L1 obsoleto. **Mitigación**: El despacho de señales de Godot es síncrono dentro del frame; `_reset_stall_timer` corre antes del siguiente physics frame. No es una race condition real.
- **Riesgo**: `_stall_level` no se resetea si `initialize_session()` se llama múltiples veces en un test. **Mitigación**: `_reset_stall_timer()` asigna `_stall_level = 0` incondicionalmente.
- **Riesgo**: La pista L3 es casi-spoiler (`cenicero` + `guardarropa` son ubicaciones reales de evidencia). **Mitigación**: Por diseño — L3 solo se dispara tras 7 min de idle; el jugador está genuinamente atascado.

---

## Requisitos GDD Cubiertos

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|------------------------|
| gdd_detective_noir_vr.md / TR-estado-002 | Pistas anti-stall L1/L2/L3 a los 4/5/7 min sin evidencia nueva | Timer en GameManager dispara exactamente a 240/300/420 s de idle acumulado; se resetea con `clue_added` |
| Esquema de telemetría ADR-0007 | Dict `anti_stall_triggers: {L1, L2, L3}` incrementado por evento | `_on_stall_timer_timeout()` incrementa `anti_stall_triggers[level_key]` antes de emitir la señal |

---

## Implicaciones de Rendimiento
- **CPU**: Negligible — un nodo Timer de Godot, callback ~3× por sesión máximo.
- **Memoria**: Un nodo Timer + tres strings constantes. Inapreciable.
- **Tiempo de Carga**: Ninguno.
- **Red**: Ninguno.

---

## Plan de Migración
Se debe extender `initialize_session()` de ADR-0001 para:
1. Instanciar `_stall_timer = Timer.new()` con `one_shot = true`
2. Agregar como hijo: `add_child(_stall_timer)`
3. Conectar: `_stall_timer.timeout.connect(_on_stall_timer_timeout)`
4. Iniciar: `_stall_timer.start(STALL_THRESHOLDS[0])`

`add_clue()` debe llamar `_reset_stall_timer()` después de emitir `clue_added`.

GajitoModule debe conectarse a `GameManager.anti_stall_triggered` en su `_ready()`.

No se rompe código existente — solo cambios aditivos en GameManager y GajitoModule.

---

## Criterios de Validación
- Con `STALL_THRESHOLDS = [5.0, 3.0, 3.0]` (valores de test), L1 dispara a los 5 s, L2 a los 8 s, L3 a los 11 s sin pista agregada.
- Tras `add_clue("F1")`, el timer se resetea: el próximo L1 dispara 5 s después, `_stall_level` = 0.
- Tras disparar L3, no se emite más `anti_stall_triggered`.
- El dict `anti_stall_triggers` refleja los conteos exactos de disparos en el JSON exportado.
- El pop-up de Gajito muestra el texto en español correcto para cada nivel.

---

## Decisiones Relacionadas
- [ADR-0001](adr-0001-gamemanager-singleton.md) — Hub de estado de sesión; señal `clue_added`; dueño del dict `anti_stall_triggers`
- [ADR-0005](adr-0005-arquitectura-senales.md) — Reglas de capas de señales; patrón de comunicación Foundation→Feature
- [ADR-0007](adr-0007-telemetria-sesion.md) — Telemetry schema; `anti_stall_triggers` field definition
- [ADR-0009](adr-0009-balbuceo-npc.md) — GajitoModule as existing pop-up delivery mechanism
