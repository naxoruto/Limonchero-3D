extends CanvasLayer

@onready var _prompt: Label = $InteractionPrompt


func set_interaction_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""
