extends CharacterBody3D
class_name GajitoCompanion

## Compañero que sigue a Limonchero. Solo dos estados visuales: idle / walking.
## Asigna `player_path` en el inspector, o el script lo busca por nombre "Player"
## o por grupo "player".

@export var player_path: NodePath
## Distancia hacia adelante del jugador (en metros, dirección -Z del player).
@export var forward_offset: float = 1.4
## Desplazamiento lateral (negativo = izquierda del jugador, positivo = derecha).
@export var lateral_offset: float = -0.7
## Cuando sale del anchor por más de este radio, vuelve a caminar.
@export var follow_distance: float = 0.5
## Cuando entra dentro de este radio del anchor, idle.
@export var stop_distance: float = 0.25
## Velocidad de marcha.
@export var move_speed: float = 3.5
## Velocidad de rotación (rad/s) hacia la dirección de movimiento o jugador.
@export var rotation_speed: float = 8.0
## Si > 0, fija la escala uniforme del modelo.
@export var model_scale: float = 1.0

const _IDLE_KEY := "gajito_idle"
const _WALK_KEY := "gajito_walk"
const _GRAVITY := 9.8
const _IDLE_FBX := "res://assets/characters/Gajito/idle/Breathing Idle.fbx"
const _WALK_FBX := "res://assets/characters/Gajito/walk/Walking.fbx"

var _player: Node3D = null
var _anim_player: AnimationPlayer = null
var _model_root: Node3D = null
var _current_state := ""


func _ready() -> void:
	add_to_group("companions")
	_player = _resolve_player()
	if _player is CollisionObject3D:
		add_collision_exception_with(_player)
	_setup_model()
	_set_state("idle")
	_debug_log_bounds()


func _debug_log_bounds() -> void:
	if _model_root == null:
		print("[Gajito] _model_root null")
		return
	var aabb := _calc_aabb(_model_root)
	print("[Gajito] model_scale=%s aabb_size=%s aabb_pos=%s self_pos=%s player=%s" % [
		_model_root.scale,
		aabb.size,
		aabb.position,
		global_position,
		_player.global_position if _player != null else Vector3.ZERO
	])


func _calc_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in node.get_children():
		if child is VisualInstance3D:
			var box := (child as VisualInstance3D).get_aabb()
			# Transform to model_root space
			box = (child as VisualInstance3D).transform * box
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		var sub := _calc_aabb(child)
		if sub.size.length_squared() > 0:
			if first:
				result = sub
				first = false
			else:
				result = result.merge(sub)
	return result


func _physics_process(delta: float) -> void:
	if _player == null:
		_apply_gravity_only(delta)
		return

	var anchor := _compute_anchor()
	var to_anchor := anchor - global_position
	to_anchor.y = 0.0
	var distance := to_anchor.length()

	var should_walk := false
	if _current_state == "walking":
		should_walk = distance > stop_distance
	else:
		should_walk = distance > follow_distance

	var horizontal_velocity := Vector3.ZERO
	if should_walk and distance > 0.001:
		var direction := to_anchor / distance
		# Limitar velocidad para no sobrepasar el anchor en un frame.
		var step_speed: float = min(move_speed, distance / max(delta, 0.0001))
		horizontal_velocity = direction * step_speed
		_face_direction(direction, delta)
		_set_state("walking")
	else:
		_face_player(delta)
		_set_state("idle")

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if not is_on_floor():
		velocity.y -= _GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _compute_anchor() -> Vector3:
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := _player.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	return _player.global_position + forward * forward_offset + right * lateral_offset


func _face_player(delta: float) -> void:
	if _model_root == null or _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return
	var direction := to_player.normalized()
	var target_yaw := atan2(direction.x, direction.z)
	var current_yaw := _model_root.rotation.y
	_model_root.rotation.y = lerp_angle(current_yaw, target_yaw, clamp(rotation_speed * delta, 0.0, 1.0))


func _apply_gravity_only(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _face_direction(direction: Vector3, delta: float) -> void:
	if _model_root == null:
		return
	# Mixamo idle/walk mira a +Z local. Aplicamos yaw al modelo, no al cuerpo,
	# para no enredar la lógica de movimiento.
	var target_yaw := atan2(direction.x, direction.z)
	var current_yaw := _model_root.rotation.y
	_model_root.rotation.y = lerp_angle(current_yaw, target_yaw, clamp(rotation_speed * delta, 0.0, 1.0))


func _set_state(state: String) -> void:
	if _current_state == state:
		return
	_current_state = state
	if _anim_player == null:
		return
	var key := _IDLE_KEY if state == "idle" else _WALK_KEY
	if _anim_player.has_animation(key):
		_anim_player.play(key)


func _resolve_player() -> Node3D:
	if not player_path.is_empty():
		var n := get_node_or_null(player_path)
		if n is Node3D:
			return n
	var by_group := get_tree().get_first_node_in_group("player")
	if by_group is Node3D:
		return by_group
	var root := get_tree().current_scene
	if root != null:
		var by_name := root.find_child("Player", true, false)
		if by_name is Node3D:
			return by_name
	return null


func _setup_model() -> void:
	var base: PackedScene = load(_WALK_FBX)
	if base == null:
		push_error("GajitoCompanion: no se pudo cargar %s" % _WALK_FBX)
		return
	var instance := base.instantiate()
	add_child(instance)
	if instance is Node3D:
		_model_root = instance as Node3D
		if model_scale > 0.0:
			_model_root.scale = Vector3.ONE * model_scale
	_anim_player = _find_animation_player(instance)
	if _anim_player == null:
		push_warning("GajitoCompanion: AnimationPlayer no encontrado.")
		return
	_inject_animations()


func _inject_animations() -> void:
	_extract_anim_to_default_lib(_anim_player, _WALK_KEY)
	var idle_scene: PackedScene = load(_IDLE_FBX)
	if idle_scene != null:
		_inject_scene_anim(idle_scene, _IDLE_KEY)
	else:
		push_warning("GajitoCompanion: no se pudo cargar idle FBX.")


func _get_default_lib() -> AnimationLibrary:
	if not _anim_player.has_animation_library(""):
		_anim_player.add_animation_library("", AnimationLibrary.new())
	return _anim_player.get_animation_library("")


func _extract_anim_to_default_lib(player: AnimationPlayer, key: String) -> void:
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			if anim_name == "RESET":
				continue
			var anim: Animation = lib.get_animation(anim_name).duplicate()
			anim.loop_mode = Animation.LOOP_LINEAR
			_get_default_lib().add_animation(key, anim)
			return


func _inject_scene_anim(source_scene: PackedScene, key: String) -> void:
	var instance := source_scene.instantiate()
	var src_player := _find_animation_player(instance)
	if src_player != null:
		for lib_name in src_player.get_animation_library_list():
			var lib := src_player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				if anim_name == "RESET":
					continue
				var anim: Animation = lib.get_animation(anim_name).duplicate()
				anim.loop_mode = Animation.LOOP_LINEAR
				_get_default_lib().add_animation(key, anim)
				instance.queue_free()
				return
	instance.queue_free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
