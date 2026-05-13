extends CharacterBody3D

const WALK_SPEED: float = 4.0
const SPRINT_SPEED: float = 7.0
const GRAVITY: float = 9.8

const EYE_HEIGHT_ABOVE_FEET: float = 1.55
const CAMERA_PITCH_LIMIT: float = deg_to_rad(85.0)


@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D

var _input_enabled := true
var _pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Keep the camera at eye height even if edited by mistake.
	# CharacterBody3D origin is typically at the collider center, not at the feet.
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D if col != null else null
	if capsule != null:
		var half_total_height := capsule.height * 0.5 + capsule.radius
		camera.position.y = -half_total_height + EYE_HEIGHT_ABOVE_FEET
	else:
		camera.position.y = EYE_HEIGHT_ABOVE_FEET


func enable_input(enabled: bool) -> void:
	_input_enabled = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			-CAMERA_PITCH_LIMIT,
			CAMERA_PITCH_LIMIT
		)
		camera.rotation.x = _pitch
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Sandbox convenience: toggle capture.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not _input_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_x := 0.0
	var input_z := 0.0
	if Input.is_key_pressed(KEY_A):
		input_x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_z += 1.0

	var direction := (transform.basis * Vector3(input_x, 0.0, input_z)).normalized()
	# Godot 4: no KEY_SHIFT_L/KEY_SHIFT_R; KEY_SHIFT covers both.
	var sprint_pressed := Input.is_key_pressed(KEY_SHIFT)
	var speed := SPRINT_SPEED if sprint_pressed else WALK_SPEED

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
