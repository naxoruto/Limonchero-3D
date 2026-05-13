# ADR-0012: Controlador del Jugador (Player Controller)

## Estado
Propuesto

## Date
2026-05-01

## Engine Compatibility

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | Core / Input |
| **Riesgo de Conocimiento** | LOW — CharacterBody3D, Input y Camera3D son APIs estables desde Godot 4.0 |
| **Referencias Consultadas** | ADR-0001 (GameManager), ADR-0005 (arquitectura de señales), TR-jugador-001/002 |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | Sensibilidad de mouse en Linux vs. Windows; input de mando con `Input.get_vector()` en build exportado |

## ADR Dependencies

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager — sesión debe estar inicializada antes de que el jugador se mueva) |
| **Habilita** | ADR-0013 Interaction System (el RayCast3D de interacción es hijo de Camera3D definida aquí) |
| **Bloquea** | Epic "Exploración del Nivel" — no puede implementarse sin este ADR |
| **Nota de Orden** | Camera3D debe existir antes de que ADR-0013 pueda anclar su RayCast3D |

---

## Contexto

### Problema
No existe un ADR que documente cómo se implementa el movimiento FPS del jugador: qué nodo raíz usar, cómo se integra la cámara, cómo se maneja el mouse y el mando, y cuáles son las velocidades canónicas. Sin esta decisión, distintos programadores pueden implementar el controlador de formas incompatibles con la arquitectura de señales (ADR-0005) y el sistema de interacción (ADR-0013).

### Restricciones
- Plataforma PC: Windows y Linux. Sin XR/VR (eliminado en v0.3).
- Controles: WASD + mouse (primario), mando opcional (joystick izquierdo + L3 para sprint).
- PTT en tecla V (teclado) / LB (mando) — implementado en capa de audio separada, no aquí.
- El controlador no posee estado de sesión; toda telemetría va a GameManager.
- La cámara debe exponer un nodo accesible para que ADR-0013 ancle el RayCast3D.

### Requisitos
- Movimiento FPS con WASD + look de mouse (sensibilidad configurable)
- Sprint con Shift (teclado) / L3 (mando) — velocidad aumentada mientras se mantiene
- Soporte de mando mediante `Input.get_vector()` para movimiento analógico
- `mouse_mode = Input.MOUSE_MODE_CAPTURED` durante gameplay; liberado en menús/pausa
- Gravedad y colisión mediante `CharacterBody3D.move_and_slide()`
- El jugador no puede saltar (juego de interiores, no hay plataformas)
- Velocidad de caminar: 4.0 m/s; velocidad de sprint: 7.0 m/s

---

## Decisión

El jugador se implementa como escena `player.tscn` con raíz `CharacterBody3D`. Una `Camera3D` es hijo directo del nodo raíz (posicionada a altura de ojos ≈ 1.65 m). El movimiento se procesa en `_physics_process()` usando `move_and_slide()`. El look de mouse se aplica rotando el nodo raíz en Y y la cámara en X (con clamp ±85°). El soporte de mando usa `Input.get_vector()` para movimiento y `Input.get_axis()` para el look analógico.

El script del jugador (`player_controller.gd`) no escribe estado en GameManager directamente — solo emite señales si la posición es relevante para otros sistemas. No posee lógica de interacción (delegada a ADR-0013).

### Diagrama de Arquitectura

```
player.tscn
├── CharacterBody3D  [player_controller.gd]
│   ├── CollisionShape3D  (CapsuleShape3D h=1.8m r=0.4m)
│   └── Camera3D           ← Nodo accesible como $Camera3D
│       └── (RayCast3D se añade aquí en ADR-0013)
│
│   _physics_process(delta):
│     1. Leer input → direction: Vector3 (WASD + joystick izq.)
│     2. Aplicar velocidad (WALK_SPEED o SPRINT_SPEED según Shift/L3)
│     3. Aplicar gravedad si !is_on_floor()
│     4. move_and_slide()
│
│   _input(event):
│     Si InputEventMouseMotion → rotar nodo Y + cámara X (clamp)
│     Si InputEventJoypadMotion (joystick der.) → look analógico
```

### Interfaces Clave

```gdscript
# res://scripts/core/player_controller.gd
extends CharacterBody3D

# ── Constantes ────────────────────────────────────────────────────────────────
const WALK_SPEED: float = 4.0      # m/s
const SPRINT_SPEED: float = 7.0    # m/s
const MOUSE_SENSITIVITY: float = 0.002   # radianes por pixel (ajustable en opciones)
const GAMEPAD_LOOK_SENSITIVITY: float = 2.5  # multiplicador para look analógico
const GRAVITY: float = 9.8
const CAMERA_HEIGHT: float = 1.65  # metros desde base del CharacterBody3D
const CAMERA_PITCH_LIMIT: float = deg_to_rad(85.0)

# ── Nodo accesible ────────────────────────────────────────────────────────────
@onready var camera: Camera3D = $Camera3D

# ── Estado privado ────────────────────────────────────────────────────────────
var _pitch: float = 0.0  # rotación acumulada en X de la cámara

# ── Señales ───────────────────────────────────────────────────────────────────
# (Ninguna en v1. La posición se lee directamente si ADR-0013 la necesita.)

# ── API pública ───────────────────────────────────────────────────────────────
func set_mouse_sensitivity(value: float) -> void  # llamado desde menú opciones
func enable_input(enabled: bool) -> void          # desactiva controles en cutscenes/menús
```

---

## Alternativas Consideradas

### Alternativa A: KinematicBody3D (API de Godot 3)
- **Descripción**: Usar `move_and_collide()` con lógica manual de deslizamiento.
- **Pros**: Familiar si el equipo tiene experiencia en Godot 3.
- **Contras**: `KinematicBody3D` no existe en Godot 4. Sería un error de compilación.
- **Razón de Rechazo**: API obsoleta. El proyecto usa Godot 4.

### Alternativa B: RigidBody3D con impulsos
- **Descripción**: El jugador es un cuerpo rígido; el movimiento se aplica con `apply_central_impulse()`.
- **Pros**: Física "gratuita" para colisiones complejas.
- **Contras**: El movimiento FPS con RigidBody3D es errático y difícil de controlar. La cámara tiembla por la simulación física. Requiere constraints adicionales para evitar que el personaje caiga.
- **Razón de Rechazo**: Overkill para un juego de exploración de interiores. CharacterBody3D es el patrón canónico de Godot 4 para personajes FPS/TPS.

---

## Consecuencias

### Positivas
- `CharacterBody3D` + `move_and_slide()` es el patrón estándar de Godot 4 para FPS — bien documentado, predecible.
- `Camera3D` como hijo directo del nodo raíz simplifica la posición del RayCast3D para ADR-0013.
- `enable_input(false)` permite congelar controles durante menús y cutscenes sin destruir la escena.
- MOUSE_SENSITIVITY como constante exportable permite ajuste por opciones sin modificar código.

### Negativas
- Sin física de rebote ni empuje de objetos — aceptado para este tipo de juego.
- El look analógico de mando requiere calibración manual de `GAMEPAD_LOOK_SENSITIVITY`. Se ajustará en playtest.

### Riesgos
- **Riesgo**: `mouse_mode` no se restaura al salir al menú, dejando el cursor capturado. **Mitigación**: `enable_input(false)` también libera el cursor; conectar a señal de pausa/menú.
- **Riesgo**: Diferencia de sensibilidad de mouse entre Linux y Windows por DPI del sistema. **Mitigación**: Aplicar `event.relative * MOUSE_SENSITIVITY` — Godot normaliza el delta relativo por plataforma. Verificar en build Linux antes de demo.
- **Riesgo**: L3 (joystick presionado) puede conflictuar con otros mandos si se usa mapeo de botones distinto. **Mitigación**: Usar Input Map de Godot con acción nombrada `sprint` mapeada a L3 — el equipo puede remapear sin tocar el código.

---

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|------------------------|
| gdd_detective_noir_vr.md / TR-jugador-001 | FPS movement — CharacterBody3D + Camera3D, WASD/mouse + gamepad | Implementación exacta descrita en sección Decisión |
| gdd_detective_noir_vr.md / TR-jugador-002 | Sprint con Shift (teclado) / L3 (mando) | `SPRINT_SPEED = 7.0 m/s` activado con acción `sprint` |
| gdd_detective_noir_vr.md / RF-01 | El jugador puede navegar todas las zonas accesibles con WASD/mouse o joystick | `CharacterBody3D.move_and_slide()` + soporte `Input.get_vector()` para mando |

---

## Implicaciones de Rendimiento
- **CPU**: Despreciable — `move_and_slide()` es O(1) por frame. Un solo CharacterBody3D.
- **Memoria**: Una escena de nodos ligeros. Sin assets adicionales.
- **Tiempo de Carga**: Ninguno.
- **Red**: Ninguno.

---

## Plan de Migración
ADR nuevo — no hay código existente que migrar. Primera implementación.

Pasos de integración con ADRs existentes:
1. `player.tscn` se instancia en `el_agave_y_la_luna.tscn` (nivel principal).
2. ADR-0013 (Interaction System) añade `RayCast3D` como hijo de `$Camera3D` definida aquí.
3. ADR-0017 (HUD System) se superpone como `CanvasLayer` — no depende de la escena del jugador.

---

## Criterios de Validación
- El jugador se mueve a 4 m/s (cronometrado en el nivel con regla de distancia conocida).
- El sprint aumenta la velocidad a 7 m/s mientras se mantiene Shift/L3.
- El look de mouse no produce drift ni gimbal lock.
- El mouse queda liberado al abrir el menú de pausa; se captura al cerrarlo.
- El movimiento con joystick analógico no produce jitter a velocidades bajas (zona muerta funcional).
- El jugador no atraviesa paredes ni muebles con colisión configurada.

---

## Decisiones Relacionadas
- [ADR-0001](adr-0001-gamemanager-singleton.md) — GameManager: sesión inicializada antes del movimiento
- [ADR-0005](adr-0005-arquitectura-senales.md) — Señales para comunicación ascendente si el controlador necesita notificar
- [ADR-0011](adr-0011-anti-stall-system.md) — Anti-stall mide inactividad de evidencia, no movimiento del jugador
- [ADR-0013](adr-0013-interaction-system.md) — RayCast3D anclado a Camera3D definida aquí
