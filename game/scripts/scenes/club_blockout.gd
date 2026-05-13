extends Node3D

@onready var _interaction_system: Node = $Player/InteractionSystem
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	_interaction_system.focus_label_changed.connect(_on_focus_label_changed)
	_on_focus_label_changed("")


func _on_focus_label_changed(label: String) -> void:
	_hud.call("set_interaction_prompt", label)
