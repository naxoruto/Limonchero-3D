extends Node3D
## Reproduce automaticamente la primera animacion no-RESET del modelo importado.
## Pensado para FBX de Mixamo usados como cuerpos / poses estaticas.

func _ready() -> void:
	var player := _find_animation_player(self)
	if player == null:
		push_warning("static_corpse '%s': sin AnimationPlayer." % name)
		return
	for lib_name in player.get_animation_library_list():
		var lib: AnimationLibrary = player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			if String(anim_name) == "RESET":
				continue
			var full: String = String(anim_name) if String(lib_name) == "" else "%s/%s" % [lib_name, anim_name]
			var anim: Animation = lib.get_animation(anim_name)
			anim.loop_mode = Animation.LOOP_LINEAR
			player.play(full)
			return


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
