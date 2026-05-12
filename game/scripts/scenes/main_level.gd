extends Node3D

const FADE_DURATION := 0.6

@onready var _interaction_system: Node = $Player/InteractionSystem
@onready var _hud: CanvasLayer = $HUD
@onready var _dialogue: CanvasLayer = $DialogueUI
@onready var _player: CharacterBody3D = $Player
@onready var _fade: ColorRect = $FadeOverlay/FadeRect

var _player_camera: Camera3D = null
var _active_npc: Node = null
var _history: Array = []  # historial conversacion del NPC activo
var _pending_player_text: String = ""


func _ready() -> void:
	_player_camera = _player.get_node("Camera3D")
	_interaction_system.focus_label_changed.connect(_on_focus_label_changed)
	_on_focus_label_changed("")
	_dialogue.close_requested.connect(_on_close_requested)
	_dialogue.recording_started.connect(_on_recording_started)
	_dialogue.recording_stopped.connect(_on_recording_stopped)
	VoiceManager.audio_captured.connect(_on_audio_captured)
	LLMClient.stt_completed.connect(_on_stt_completed)
	LLMClient.stt_failed.connect(_on_stt_failed)
	LLMClient.npc_response_ready.connect(_on_npc_response_ready)
	LLMClient.npc_request_failed.connect(_on_npc_request_failed)
	_fade.color = Color(0, 0, 0, 0)

	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.dialogue_requested.connect(_on_dialogue_requested)


func _on_recording_started() -> void:
	if _active_npc == null:
		return
	VoiceManager.start_recording()


func _on_recording_stopped() -> void:
	if _active_npc == null:
		return
	VoiceManager.stop_recording()


func _on_audio_captured(wav_bytes: PackedByteArray) -> void:
	if _active_npc == null:
		return
	LLMClient.request_stt(wav_bytes)


func _on_stt_completed(transcript: String) -> void:
	if _active_npc == null:
		return
	var text := transcript.strip_edges()
	if text.is_empty():
		_dialogue.add_npc_message("[color=yellow]No se detecto voz.[/color]")
		return
	_pending_player_text = text
	_dialogue.add_player_message(text)
	LLMClient.request_npc(_active_npc.npc_id, text, _history)


func _on_stt_failed(error: String) -> void:
	_dialogue.add_npc_message("[color=red][Error STT: %s][/color]" % error)


func _on_npc_response_ready(npc_id: String, text: String) -> void:
	if _active_npc == null or _active_npc.npc_id != npc_id:
		return
	if not _pending_player_text.is_empty():
		_history.append({"role": "user", "content": _pending_player_text})
		_pending_player_text = ""
	_history.append({"role": "assistant", "content": text})
	_dialogue.add_npc_message(text)


func _on_npc_request_failed(_npc_id: String, error: String) -> void:
	_dialogue.add_npc_message("[color=red][Error: %s][/color]" % error)


func _on_focus_label_changed(label: String) -> void:
	if _active_npc != null:
		_hud.set_interaction_prompt("")
		return
	_hud.set_interaction_prompt(label)


func _on_dialogue_requested(npc: Node) -> void:
	if _active_npc != null:
		return
	_active_npc = npc
	_history.clear()
	_pending_player_text = ""
	_hud.set_interaction_prompt("")
	_fade_then(func():
		_player.enable_input(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		npc.switch_to_dialogue_camera()
		_dialogue.show_panel(npc)
	)


func _on_close_requested() -> void:
	if _active_npc == null:
		return
	var npc := _active_npc
	_active_npc = null
	_pending_player_text = ""
	_fade_then(func():
		_dialogue.hide_panel()
		_player_camera.make_current()
		npc.close_dialogue()
		_player.enable_input(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)


func _fade_then(action: Callable) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0, 0, 0, 1), FADE_DURATION)
	tween.tween_callback(action)
	tween.tween_property(_fade, "color", Color(0, 0, 0, 0), FADE_DURATION)
