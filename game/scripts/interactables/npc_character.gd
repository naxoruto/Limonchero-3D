extends Node3D

signal dialogue_requested(npc: Node)

@export var interaction_label: String = "Hablar"
@export var npc_name: String = "NPC"
@export var npc_id: String = ""
## Carpeta base del personaje. Si se asigna, las animaciones y modelo
## se descubren automaticamente desde subcarpetas:
##   {folder}/animation idle/  → idle_scene
##   {folder}/animation scene/ → talking_scene
##   {folder}/T-pose/ o t-pose/ → model_scene
## Solo se asignan si la propiedad correspondiente esta vacia.
@export var character_folder: String = ""
## Escena base del personaje (modelo + esqueleto, idealmente en T-pose).
## Si es null, se usa talking_scene o idle_scene como fallback.
@export var model_scene: PackedScene = null
## FBX con animacion idle (mismo esqueleto que model_scene).
@export var idle_scene: PackedScene = null
## FBX con animacion de hablar (mismo esqueleto que model_scene).
@export var talking_scene: PackedScene = null
@export var face_height: float = 1.6
@export var cam_distance: float = 0.8
@export var cam_offset_x: float = 0.4

var _anim_player: AnimationPlayer = null
var _dialogue_camera: Camera3D = null
var _in_dialogue: bool = false
var _prev_camera: Camera3D = null
var _skeleton: Skeleton3D = null
var _hip_bone_idx: int = -1
var _hitbox_area: Area3D = null

const _IDLE_KEY := "npc_idle"
const _TALK_KEY := "npc_talking"


func _ready() -> void:
	add_to_group("npcs")
	_add_dialogue_camera()
	if not character_folder.is_empty():
		_discover_animations_from_folder()
	var model_instance := _setup_model()
	if model_instance == null:
		push_warning("NpcCharacter '%s': ninguna escena asignada (model/idle/talking)." % name)
		_add_hitbox()
		return
	_anim_player = _find_animation_player(model_instance)
	if _anim_player == null:
		push_warning("NpcCharacter '%s': no AnimationPlayer encontrado en el modelo." % name)
	else:
		_inject_animations()
	if not _add_skeletal_hitbox(model_instance):
		_add_hitbox()
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
	capsule.radius = 1.5 / s.x
	capsule.height = 2.0 / s.y
	shape.shape = capsule
	shape.position.y = 1.0 / s.y
	area.add_child(shape)
	add_child(area)


func _add_skeletal_hitbox(model_instance: Node) -> bool:
	var skel := _find_skeleton(model_instance)
	if skel == null:
		return false
	var bone_idx := _find_hip_bone(skel)
	if bone_idx < 0:
		return false
	_skeleton = skel
	_hip_bone_idx = bone_idx
	var area := Area3D.new()
	area.top_level = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	shape.shape = capsule
	area.add_child(shape)
	add_child(area)
	_hitbox_area = area
	set_process(true)
	return true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


func _find_hip_bone(skel: Skeleton3D) -> int:
	var preferred := ["mixamorig:Hips", "Hips", "Hip", "pelvis", "Pelvis"]
	for n in preferred:
		var idx := skel.find_bone(n)
		if idx >= 0:
			return idx
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).to_lower().contains("hip"):
			return i
	return 0


func _process(_delta: float) -> void:
	if _skeleton != null and _hip_bone_idx >= 0 and _hitbox_area != null:
		var bone_pose := _skeleton.get_bone_global_pose(_hip_bone_idx)
		_hitbox_area.global_position = _skeleton.global_transform * bone_pose.origin


func _discover_animations_from_folder() -> void:
	if idle_scene == null:
		idle_scene = _find_first_scene_in(character_folder.path_join("animation idle"))
	if talking_scene == null:
		talking_scene = _find_first_scene_in(character_folder.path_join("animation scene"))
	if model_scene == null:
		var tpose := _find_first_scene_in(character_folder.path_join("T-pose"))
		if tpose == null:
			tpose = _find_first_scene_in(character_folder.path_join("t-pose"))
		model_scene = tpose


func _find_first_scene_in(dir_path: String) -> PackedScene:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.ends_with(".fbx") or lower.ends_with(".glb") or lower.ends_with(".gltf"):
				dir.list_dir_end()
				return load(dir_path.path_join(file_name)) as PackedScene
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


func _setup_model() -> Node:
	var base := model_scene
	if base == null:
		base = talking_scene
	if base == null:
		base = idle_scene
	if base == null:
		return null
	var instance := base.instantiate()
	add_child(instance)
	return instance


func _inject_animations() -> void:
	var base_scene: PackedScene = model_scene
	if base_scene == null:
		base_scene = talking_scene
	if base_scene == null:
		base_scene = idle_scene

	if talking_scene != null and talking_scene != base_scene:
		_inject_scene_anim(talking_scene, _TALK_KEY)
	else:
		_extract_anim_to_default_lib(_anim_player, _TALK_KEY)

	if idle_scene != null and idle_scene != base_scene:
		_inject_scene_anim(idle_scene, _IDLE_KEY)
	else:
		_extract_anim_to_default_lib(_anim_player, _IDLE_KEY)


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
			var anim := lib.get_animation(anim_name).duplicate() as Animation
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
