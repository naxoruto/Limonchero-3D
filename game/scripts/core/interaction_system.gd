extends Node3D

signal focus_label_changed(label: String)
signal focus_changed(node: Node)

@export var max_distance: float = 2.0

@onready var raycast: RayCast3D = $RayCast3D

var _camera: Camera3D = null

var _focused: Object = null
var _interact_just_pressed := false


func _ready() -> void:
	# Ensure ray length matches exported setting.
	raycast.target_position = Vector3(0.0, 0.0, -max_distance)
	raycast.enabled = true
	raycast.collide_with_bodies = true
	raycast.collide_with_areas = true
	# Don't let the ray hit the player's own body.
	raycast.exclude_parent = true

	# Prefer the player's camera; fall back to the viewport camera if needed.
	var parent := get_parent()
	if parent != null:
		_camera = parent.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d()


func _process(_delta: float) -> void:
	# Make the ray follow the camera (including looking up/down).
	if _camera != null:
		raycast.global_transform = _camera.global_transform

	raycast.force_raycast_update()
	var collider := raycast.get_collider()
	var new_focused: Object = _find_interactable(collider)

	if new_focused != _focused:
		_focused = new_focused
		focus_label_changed.emit(_get_interaction_label(_focused))
		focus_changed.emit(_focused)

	if _interact_just_pressed:
		if _focused != null:
			# Duck-typed contract: interact()
			_focused.call("interact")
			# Sandbox feedback in editor output.
			print("Interact pressed on: %s" % _focused)
		else:
			print("Interact pressed, but nothing is focused")
	_interact_just_pressed = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact_just_pressed = true


func _find_interactable(obj: Object) -> Object:
	var node := obj as Node
	while node != null:
		if node.has_method("interact"):
			return node
		node = node.get_parent()
	return null


func _get_interaction_label(obj: Object) -> String:
	if obj == null:
		return ""
	var label = obj.get("interaction_label")
	return label if typeof(label) == TYPE_STRING else ""
