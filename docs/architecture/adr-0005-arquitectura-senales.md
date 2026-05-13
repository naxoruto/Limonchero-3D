# ADR-0005: Arquitectura de Señales entre Capas — Comunicación Desacoplada entre Módulos

## Estado
Aceptado

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Núcleo / Scripting |
| **Riesgo de Conocimiento** | BAJO — el sistema de señales de Godot es estable desde Godot 3.x; sintaxis tipada en Godot 4 |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 signals |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que las señales tipadas (`signal foo(bar: String)`) funcionan correctamente en Godot 4.6 con conexiones vía `.connect()` |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager ya establece el patrón con sus señales) |
| **Habilita** | Todos los ADRs restantes (005–010) — este ADR define las reglas que todos los demás siguen |
| **Bloquea** | Ninguno específico — es una regla de implementación, no un prerequisito de funcionalidad |
| **Nota de Orden** | Debe revisarse antes de implementar cualquier módulo de Características o Presentación |

## Contexto

### Declaración del Problema
El proyecto tiene 16 módulos distribuidos en 5 capas. Sin una regla clara de comunicación, los desarrolladores del equipo tenderán a usar `get_node()` y llamadas directas entre capas, creando acoplamiento rígido que hace el código difícil de mantener, probar y modificar. Se necesita una convención explícita que todos puedan seguir.

### Restricciones
- Equipo de 4 personas con distintos niveles de experiencia en Godot
- GDScript — sin interfaces formales ni tipos abstractos
- La regla debe ser simple de entender y fácil de aplicar en revisión de código
- Godot 4.6 tiene señales tipadas — usar esa capacidad

### Requisitos
- Los módulos de capas superiores no deben importar ni referenciar directamente módulos de capas inferiores excepto para conectar señales
- Foundation nunca debe depender de Feature/Core/Presentation
- GameManager comunica cambios de estado solo via señales (no polling)
- La regla debe ser verificable en revisión de código sin herramientas especiales

## Decisión

**La comunicación entre capas usa exclusivamente señales Godot tipadas. Las llamadas directas a métodos solo están permitidas dentro de la misma capa o hacia abajo (capa superior llama método de capa inferior). Nunca al revés.**

### Reglas de comunicación

```
PERMITIDO:
  ✓ Capa superior llama método de capa inferior
      Feature → GameManager.add_clue("F1")           ← llamada directa hacia abajo OK
      Core → GameManager.get_clue_state("F1")         ← lectura hacia abajo OK

  ✓ Capa inferior notifica a capa superior via señal
      GameManager.emit_signal("clue_added", "F1")     ← señal hacia arriba OK
      VoiceManager.emit_signal("audio_captured", bytes)

  ✓ Conexión de señal en _ready() del módulo consumidor
      GameManager.clue_added.connect(_on_clue_added)

PROHIBIDO:
  ✗ Foundation llama método de Feature/Core/Presentation
      GameManager.get_node("HUD").update_inventory()  ← PROHIBIDO
      GameManager.get_node("NPCDialogue").start()     ← PROHIBIDO

  ✗ Módulo obtiene referencia a módulo de otra capa por jerarquía
      get_parent().get_node("OtroModulo").metodo()    ← PROHIBIDO entre capas

  ✗ Señal conectada a método que escribe estado de módulo inferior
      HUD conecta señal directamente a GameManager.clues  ← PROHIBIDO
```

### Patrón de conexión estándar

```gdscript
# En el módulo consumidor (capa superior), en _ready():
func _ready() -> void:
    # Conectar señales de módulos de capa inferior
    GameManager.clue_added.connect(_on_clue_added)
    GameManager.gate_opened.connect(_on_gate_opened)
    VoiceManager.audio_captured.connect(_on_audio_captured)

func _on_clue_added(clue_id: String) -> void:
    # Reaccionar al evento — NO escribir de vuelta a GameManager aquí
    update_inventory_display(clue_id)
```

### Declaración de señales (tipadas, en Godot 4.6)

```gdscript
# Todas las señales deben declararse con tipos explícitos
signal clue_added(clue_id: String)           # ✓ Tipada
signal audio_captured(wav_bytes: PackedByteArray)  # ✓ Tipada
signal npc_response_ready(npc_id: String, text: String)  # ✓ Tipada

# Prohibido:
signal clue_added  # ✗ Sin tipo — no usar en este proyecto
```

### Diagrama de flujo de comunicación

```
PRESENTACIÓN (HUD, Babble, Overlay)
  ↑ connect()  ↓ lectura directa si necesario
CARACTERÍSTICAS (Inventario, Diálogo NPC, Gajito, Acusación)
  ↑ connect()  ↓ llamadas directas a métodos públicos
NÚCLEO (Controlador Jugador, Interacción, Voz/PTT)
  ↑ connect()  ↓ llamadas directas a métodos públicos
FUNDACIÓN (GameManager, LLM Client, Cargador Escena, Backend)
  ↑ señales hacia arriba
  ↓ nunca llama hacia arriba

Regla de lectura: las flechas indican qué dirección está permitida.
```

### Cuándo usar señal vs. llamada directa

| Situación | Usar |
|-----------|------|
| Notificar a módulos de capa superior que algo ocurrió | Señal |
| Llamar método de capa inferior para modificar estado | Llamada directa |
| Consultar estado de capa inferior (lectura) | Llamada directa o property |
| Comunicar entre módulos del mismo nivel (ej. Feature ↔ Feature) | Señal (preferido) o llamada directa si son hermanos en escena |
| Comunicar con módulos de Presentación desde Feature | Señal siempre |

## Alternativas Consideradas

### Alternativa 1: Bus de eventos global (EventBus autoload)
- **Descripción:** Un nodo autoload `EventBus` con todas las señales del proyecto; cualquier módulo emite o escucha sin referencias directas
- **Pros:** Máximo desacoplamiento; un solo lugar para ver todos los eventos
- **Contras:** EventBus se vuelve un "god object" con cientos de señales; difícil de trazar qué módulo emite qué; Godot ya tiene un sistema de señales por nodo que cumple el mismo propósito
- **Razón de rechazo:** La complejidad del EventBus no está justificada para un proyecto con 16 módulos bien definidos. Las señales nativas de Godot por nodo son suficientes y más trazables.

### Alternativa 2: Llamadas directas con get_node() entre capas
- **Descripción:** Cada módulo obtiene referencias a otros módulos con `get_node()` y llama sus métodos directamente
- **Pros:** Simple de implementar; familiar para quien viene de otros lenguajes
- **Contras:** Acoplamiento rígido; cambiar la jerarquía de escenas rompe el código; imposible de probar en aislamiento; viola la separación por capas
- **Razón de rechazo:** Ya documentado como patrón prohibido en la arquitectura maestra.

### Alternativa 3: Patrón Observador manual (listas de callbacks)
- **Descripción:** Cada módulo mantiene una lista de callbacks suscritos; notifica manualmente
- **Pros:** Sin dependencia del motor
- **Contras:** Godot ya tiene señales que hacen esto mejor; reimplementar es trabajo innecesario; gestión manual de memoria de callbacks
- **Razón de rechazo:** Las señales nativas de Godot son la implementación canónica de Observer en este motor.

## Consecuencias

### Positivas
- Equipo puede modificar módulos individuales sin romper otros (bajo acoplamiento)
- El flujo de datos es trazable: grep por el nombre de la señal muestra todos los emisores y consumidores
- GameManager no necesita conocer HUD/UI — emite señales y cualquier módulo puede escuchar
- Facilita pruebas: se puede conectar una señal a una función de test sin modificar el módulo emisor

### Negativas
- Requires disciplina — GDScript no tiene un mecanismo de enforcement a nivel de lenguaje
- Las conexiones de señales en `_ready()` pueden olvidarse, generando bugs silenciosos (el módulo no recibe notificaciones pero no hay error)
- El flujo de ejecución es menos obvio que una llamada directa — requiere buscar qué está conectado a qué señal

### Riesgos
- **Riesgo:** Un desarrollador usa `get_node()` por conveniencia entre capas. **Mitigación:** Documentar este ADR en el onboarding del equipo; revisar en cada PR que no haya referencias cruzadas entre capas.
- **Riesgo:** Señal conectada pero el nodo emisor se libera antes de la desconexión. **Mitigación:** Usar la variante `connect(..., CONNECT_ONE_SHOT)` cuando sea apropiado; o desconectar en `_exit_tree()`.
- **Riesgo:** Señal emitida pero ningún módulo está escuchando (bug silencioso). **Mitigación:** En desarrollo, agregar `assert(clue_added.get_connections().size() > 0)` en módulos críticos para verificar que hay al menos un listener.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | Todos los sistemas — regla transversal de arquitectura | Define el patrón de comunicación que permite que 16 módulos coexistan sin acoplamiento rígido |
| gdd_detective_noir_vr.md | TR-estado-001: GameManager como fuente de verdad | GameManager solo notifica cambios via señales — nunca llama módulos de capas superiores |

## Implicaciones de Rendimiento
- **CPU:** Las señales en Godot 4.6 tienen overhead mínimo (~microsegundos por emisión); no hay impacto medible en este proyecto
- **Memoria:** Cada conexión de señal ocupa bytes; con ~30 conexiones en todo el proyecto, impacto insignificante
- **Tiempo de carga:** Sin impacto
- **Red:** No aplica

## Plan de Migración
Primera implementación — no hay código existente que migrar. Este ADR es una regla de implementación: se aplica desde el primer script escrito.

## Criterios de Validación
- En revisión de código: ningún módulo de Foundation llama `get_node()` hacia módulos de Feature/Presentation
- Todas las señales declaradas en el proyecto usan tipos explícitos (`signal foo(bar: String)`)
- GameManager no tiene referencias directas a ningún nodo de HUD/UI/Feature en su código
- Cada conexión de señal ocurre en `_ready()` del módulo consumidor (no en el emisor)

## Decisiones Relacionadas
- ADR-0001: GameManager — primer módulo que aplica este patrón (señales `clue_added`, `gate_opened`)
- ADR-0003: BackendLauncher — señales `backend_ready`, `backend_unavailable`
- ADR-0004: VoiceManager — señales `recording_started`, `audio_captured`
- Arquitectura maestra: `docs/architecture/architecture.md` sección "Regla de dependencias"
