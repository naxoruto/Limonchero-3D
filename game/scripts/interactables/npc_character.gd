extends Node3D

signal dialogue_requested(npc: Node)

@export var interaction_label: String = "[E] Hablar"
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
## Override manual de altura de cara en espacio LOCAL del NPC.
## Si es <= 0, se detecta automaticamente desde el hueso 'Head' (o AABB).
@export var face_height: float = 0.0
## Distancia de la camara a la cara, en metros mundo.
@export var cam_distance: float = 0.8
## Desplazamiento lateral de la camara, en metros mundo (eje X local del NPC).
@export var cam_offset_x: float = 0.4

var _anim_player: AnimationPlayer = null
var _dialogue_camera: Camera3D = null
var _in_dialogue: bool = false
var _prev_camera: Camera3D = null
var _skeleton: Skeleton3D = null
var _hip_bone_idx: int = -1
var _head_bone_idx: int = -1
var _head_top_bone_idx: int = -1
var _model_root: Node3D = null
var _hitbox_area: Area3D = null

const _IDLE_KEY := "npc_idle"
const _TALK_KEY := "npc_talking"


func _ready() -> void:
	add_to_group("npcs")
	_add_dialogue_camera()
	_add_world_label()
	if not character_folder.is_empty():
		_discover_animations_from_folder()
	var model_instance := _setup_model()
	if model_instance == null:
		push_warning("NpcCharacter '%s': ninguna escena asignada (model/idle/talking)." % name)
		_add_hitbox()
		return
	if model_instance is Node3D:
		_model_root = model_instance as Node3D
	_anim_player = _find_animation_player(model_instance)
	if _anim_player == null:
		push_warning("NpcCharacter '%s': no AnimationPlayer encontrado en el modelo." % name)
	else:
		_inject_animations()
	if not _add_skeletal_hitbox(model_instance):
		_add_hitbox()
	else:
		_head_bone_idx = _find_head_bone(_skeleton)
		_head_top_bone_idx = _find_head_top_bone(_skeleton)
	_play(_IDLE_KEY)


func get_dialogue_camera() -> Camera3D:
	return _dialogue_camera


func set_label_visible(vis: bool) -> void:
	var lbl := get_node_or_null("WorldLabel") as Label3D
	if lbl:
		lbl.visible = vis


func interact() -> void:
	if _in_dialogue:
		return
	_in_dialogue = true
	_prev_camera = get_viewport().get_camera_3d()
	_play(_TALK_KEY)
	_update_dialogue_camera_pose()
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
	var cam := Camera3D.new()
	cam.top_level = true
	add_child(cam)
	_dialogue_camera = cam


func _add_world_label() -> void:
	var label := Label3D.new()
	label.name = "WorldLabel"
	label.text = interaction_label
	label.font_size = 28
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color.WHITE
	label.visible = false
	label.position = Vector3(0, 1.0, 0)
	add_child(label)


func _update_dialogue_camera_pose() -> void:
	if _dialogue_camera == null:
		return
	var face_world: Vector3 = _compute_face_world()
	var basis_world: Basis = global_transform.basis.orthonormalized()
	# Camara en NPC local +Z (modelos Mixamo miran a +Z) y NPC local +X lateral.
	# cam_distance y cam_offset_x en metros mundo.
	var cam_pos: Vector3 = face_world + basis_world.z * cam_distance + basis_world.x * cam_offset_x
	# Basis alineado al NPC: camera -Z = -NPC.Z. Mira al frente del modelo, sin yaw.
	_dialogue_camera.global_transform = Transform3D(basis_world, cam_pos)


func _compute_face_world() -> Vector3:
	# Altura desde hueso Head (Y local NPC). Lateral siempre = origen NPC.
	var h: float = _compute_face_height_local()
	return global_transform * Vector3(0.0, h, 0.0)


func _compute_face_height_local() -> float:
	if face_height > 0.0:
		return face_height
	if _skeleton != null and _head_bone_idx >= 0:
		var head_pose: Transform3D = _skeleton.get_bone_global_pose(_head_bone_idx)
		var head_local: Vector3 = head_pose.origin
		if _head_top_bone_idx >= 0:
			var top_pose: Transform3D = _skeleton.get_bone_global_pose(_head_top_bone_idx)
			head_local = head_local.lerp(top_pose.origin, 0.5)
		var head_in_npc: Vector3 = global_transform.affine_inverse() * (_skeleton.global_transform * head_local)
		return head_in_npc.y
	return 1.6


func _find_head_bone(skel: Skeleton3D) -> int:
	if skel == null:
		return -1
	var preferred := ["mixamorig:Head", "Head", "head"]
	for n in preferred:
		var idx := skel.find_bone(n)
		if idx >= 0:
			return idx
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i).to_lower()
		if bn.contains("head") and not bn.contains("top") and not bn.contains("end"):
			return i
	return -1


func _find_head_top_bone(skel: Skeleton3D) -> int:
	if skel == null:
		return -1
	var preferred := ["mixamorig:HeadTop_End", "HeadTop_End", "HeadTop", "head_top"]
	for n in preferred:
		var idx := skel.find_bone(n)
		if idx >= 0:
			return idx
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i).to_lower()
		if bn.contains("head") and (bn.contains("top") or bn.contains("end")):
			return i
	return -1


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
