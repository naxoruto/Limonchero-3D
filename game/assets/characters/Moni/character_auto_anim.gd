extends Node3D

func _ready():
	# Buscamos el AnimationPlayer dentro del personaje
	var ap = get_node_or_null("AnimationPlayer")
	if ap:
		var anims = ap.get_animation_list()
		if anims.size() > 0:
			# Buscamos una que no sea 'RESET'
			for anim_name in anims:
				if anim_name != "RESET":
					ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
					ap.play(anim_name)
					print("Moni: Iniciando animacion automaticamente: ", anim_name)
					break
