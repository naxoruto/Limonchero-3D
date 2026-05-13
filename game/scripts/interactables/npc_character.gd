extends Node3D

signal dialogue_requested(npc: Node)

@export var interaction_label: String = "Hablar"
@export var npc_name: String = "NPC"
## ID que el backend usa (e.g. "moni", "barry", "lola"). Tiene que matchear NPC_PROMPTS del backend.
@export var npc_id: String = ""
## FBX con animacion idle (mismo modelo que talking_scene).
@export var idle_scene: PackedScene = null
## FBX con animacion de hablar/singing.
@export var talking_scene: PackedScene = null
## Altura de la cara en metros (world space). Ajusta si el personaje es más alto/bajo.
@export var face_height: float = 1.6
## Distancia de la camara a la cara en metros (world space).
@export var cam_distance: float = 0.8
## Offset horizontal de la camara en metros (positivo = derecha → NPC queda a la izquierda).
@export var cam_offset_x: float = 0.4

var _anim_player: AnimationPlayer = null
var _dialogue_camera: Camera3D = null
var _in_dialogue: bool = false
var _prev_camera: Camera3D = null

const _IDLE_KEY := "npc_idle"
const _TALK_KEY := "npc_talking"


func _ready() -> void:
	add_to_group("npcs")
	_add_hitbox()
	_add_dialogue_camera()
	var model_instance := _setup_model()
	if model_instance == null:
		push_warning("NpcCharacter '%s': talking_scene no asignada." % name)
		return
	_anim_player = _find_animation_player(model_instance)
	if _anim_player == null:
		push_warning("NpcCharacter '%s': no AnimationPlayer encontrado." % name)
		return
	_extract_anim_to_default_lib(_anim_player, _TALK_KEY)
	_inject_scene_anim(idle_scene, _IDLE_KEY)
	_play(_IDLE_KEY)


func get_dialogue_camera() -> Camera3D:
	return _dialogue_camera


func interact() -> void:
	if _in_dialogue:
		return
	_in_dialogue = true
	_prev_camera = get_viewport().get_camera_3d()
	_play(_TALK_KEY)
	dialogue_requested.emit(self)


func switch_to_dialogue_camera() -> void:
	if _dialogue_camera != null:
		_dialogue_camera.make_current()


func switch_to_player_camera() -> void:
	if _prev_camera != null:
		_prev_camera.make_current()
		_prev_camera = null


func close_dialogue() -> void:
	_in_dialogue = false
	_play(_IDLE_KEY)


# --- private ---

func _add_dialogue_camera() -> void:
	var s := scale
	var cam := Camera3D.new()
	cam.position = Vector3(cam_offset_x / s.x, face_height / s.y, cam_distance / s.z)
	add_child(cam)
	_dialogue_camera = cam


func _add_hitbox() -> void:
	var s := scale
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# Radio grande (1.5m) para cubrir el area donde el NPC se mueve cantando/bailando.
	capsule.radius = 1.5 / s.x
	capsule.height = 2.0 / s.y
	shape.shape = capsule
	shape.position.y = 1.0 / s.y
	area.add_child(shape)
	add_child(area)


func _setup_model() -> Node:
	if talking_scene == null:
		return null
	var instance := talking_scene.instantiate()
	add_child(instance)
	return instance


func _get_default_lib() -> AnimationLibrary:
	if not _anim_player.has_animation_library(""):
		_anim_player.add_animation_library("", AnimationLibrary.new())
	return _anim_player.get_animation_library("")


func _extract_anim_to_default_lib(player: AnimationPlayer, key: String) -> void:
	# FBX animations land in named libraries — find and copy the first non-RESET one.
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			if anim_name == "RESET":
				continue
			var anim := lib.get_animation(anim_name).duplicate() as Animation
			anim.loop_mode = Animation.LOOP_LINEAR
			_get_default_lib().add_animation(key, anim)
			return


func _inject_scene_anim(source_scene: PackedScene, key: String) -> void:
	if source_scene == null:
		return
	var instance := source_scene.instantiate()
	var src_player := _find_animation_player(instance)
	if src_player != null:
		for lib_name in src_player.get_animation_library_list():
			var lib := src_player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				if anim_name == "RESET":
					continue
				var anim := lib.get_animation(anim_name).duplicate() as Animation
				anim.loop_mode = Animation.LOOP_LINEAR
				_get_default_lib().add_animation(key, anim)
				instance.queue_free()
				return
	instance.queue_free()


func _play(key: String) -> void:
	if _anim_player == null:
		return
	if _anim_player.has_animation(key):
		_anim_player.play(key)
	else:
		push_warning("NpcCharacter '%s': animacion '%s' no encontrada." % [name, key])


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
