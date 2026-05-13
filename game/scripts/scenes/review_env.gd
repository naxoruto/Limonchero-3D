## review_env.gd
## Garantiza que el WorldEnvironment oscuro esté activo en runtime,
## sin importar qué Project Settings tenga el proyecto.
extends Node

func _ready() -> void:
	# Forzar el environment desde código — más fiable que solo el .tscn
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.12, 0.10)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false

	# Buscar o crear WorldEnvironment
	var we := get_tree().root.find_child("WorldEnvironment", true, false)
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		get_parent().add_child(we)
		print("[review_env] WorldEnvironment creado por GDScript")
	else:
		print("[review_env] WorldEnvironment encontrado en árbol")

	we.environment = env
	print("[review_env] Environment oscuro aplicado — background: (0.06, 0.05, 0.04)")
