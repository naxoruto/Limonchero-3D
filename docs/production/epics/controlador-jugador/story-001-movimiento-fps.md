# Story 001: Movimiento FPS — WASD + Mouse + Mando

> **Epic**: Controlador del Jugador
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4-5 horas

## Context

**ADR Governing Implementation**: [ADR-0012: Player Controller](../../../docs/architecture/adr-0012-player-controller.md)  
**ADR Decision Summary**: CharacterBody3D + Camera3D. MOUSE_SENSITIVITY configurable. `enable_input(false)` libera cursor. Comunicación hacia capas superiores solo por señales.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW  
**Engine Notes**: Verificar sensibilidad de mouse en build exportado Linux/Windows — puede diferir del editor.

---

## Acceptance Criteria

- [ ] `CharacterBody3D` con `Camera3D` hijo implementado en `scripts/player/player_controller.gd`
- [ ] Movimiento WASD + joystick izquierdo (gamepad)
- [ ] Rotación de cámara con mouse + joystick derecho (gamepad)
- [ ] Sprint: mantener Shift (teclado) / L3 (mando) → velocidad ×1.6
- [ ] Cursor capturado al iniciar juego, liberado al abrir pausa/overlay
- [ ] `enable_input(enabled: bool)` pausa/reactiva todo input del jugador
- [ ] FOV configurable — valor por defecto 80°, rango 70–110°
- [ ] No atraviesa paredes (colisiones correctas con la geometría del nivel)
- [ ] Señal `interacted` emitida al presionar E (consumida por InteractionSystem)

## Implementation Notes

```gdscript
# scripts/player/player_controller.gd
extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const MOUSE_SENSITIVITY := 0.002
const GRAVITY := 9.8
const JUMP_VELOCITY := 0.0  # sin salto

@export var fov: float = 80.0

@onready var camera: Camera3D = $Camera3D

var _input_enabled: bool = true

signal interacted(target: Node3D)

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    camera.fov = fov

func _unhandled_input(event: InputEvent) -> void:
    if not _input_enabled:
        return
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
        camera.rotation.x = clamp(camera.rotation.x, -PI/2.5, PI/2.5)
    if event.is_action_pressed("interact"):
        interacted.emit(null)  # InteractionSystem determina target via raycast

func _physics_process(delta: float) -> void:
    if not _input_enabled:
        return
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    var sprinting := Input.is_action_pressed("sprint")
    var speed := SPRINT_SPEED if sprinting else WALK_SPEED
    var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    move_and_slide()

func enable_input(enabled: bool) -> void:
    _input_enabled = enabled
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
```

**Input Map** (agregar en Project Settings → Input Map):
- `interact` → tecla E + gamepad button X/Square
- `sprint` → tecla Shift + gamepad L3
- `move_forward/back/left/right` → WASD + gamepad left joystick
- `ptt` → tecla V + gamepad LB/L1 (usado por VoiceManager)

## Test File

`tests/unit/core/player_controller_test.gd`  
- Test: `enable_input(false)` → `Input.mouse_mode == MOUSE_MODE_VISIBLE`  
- Test: velocity.x == 0 cuando `_input_enabled == false`
