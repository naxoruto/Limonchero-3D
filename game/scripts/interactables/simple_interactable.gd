extends StaticBody3D

@export var interaction_label: String = "Interact"


func interact() -> void:
	print("Interacted with: %s" % name)
