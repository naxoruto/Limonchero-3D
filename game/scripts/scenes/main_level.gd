extends Node3D

const FADE_DURATION := 0.6
const HISTORY_MAX_MESSAGES := 20

@onready var _interaction_system: Node = $Player/InteractionSystem
@onready var _dialogue: CanvasLayer = $DialogueUI
@onready var _player: CharacterBody3D = $Player
@onready var _fade: ColorRect = $FadeOverlay/FadeRect
@onready var _pause_menu: CanvasLayer = $PauseMenu

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _player_camera: Camera3D = null
var _active_npc: Node = null
var _histories: Dictionary = {}
var _pending_player_text: String = ""


func _ready() -> void:
	_player_camera = _player.get_node("Camera3D")
	_interaction_system.focus_label_changed.connect(_on_focus_label_changed)
	_interaction_system.focus_changed.connect(_on_focus_changed)
	_on_focus_label_changed("")
	_dialogue.close_requested.connect(_on_close_requested)
	_dialogue.recording_started.connect(_on_recording_started)
	_dialogue.recording_stopped.connect(_on_recording_stopped)
	_dialogue.playback_requested.connect(_on_playback_requested)
	_dialogue.retry_recording.connect(_on_retry_recording)
	_dialogue.audio_confirmed.connect(_on_audio_confirmed)
	_dialogue.text_confirmed.connect(_on_text_confirmed)
	_dialogue.retry_from_text.connect(_on_retry_from_text)
	_dialogue.gajito_correction_acknowledged.connect(_on_gajito_correction_acknowledged)
	LLMClient.gajito_evaluation_ready.connect(_on_gajito_evaluation_ready)
	LLMClient.gajito_evaluation_failed.connect(_on_gajito_evaluation_failed)
	VoiceManager.audio_captured.connect(_on_audio_captured)
	LLMClient.stt_completed.connect(_on_stt_completed)
	LLMClient.stt_failed.connect(_on_stt_failed)
	LLMClient.npc_response_ready.connect(_on_npc_response_ready)
	LLMClient.npc_request_failed.connect(_on_npc_request_failed)
	_fade.color = Color(0, 0, 0, 0)

	_pause_menu.bind_player(_player)
	_pause_menu.resumed.connect(_on_pause_resumed)
	_pause_menu.exit_to_main_menu.connect(_on_exit_to_main_menu)
	set_process_unhandled_input(true)

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


func _on_audio_captured(_wav_bytes: PackedByteArray) -> void:
	if _active_npc == null:
		return
	# El audio queda cacheado en VoiceManager. Mostrar panel de revisión;
	# el STT se dispara cuando el jugador confirme.
	_dialogue.show_audio_review()


func _on_playback_requested() -> void:
	if not VoiceManager.has_last_audio():
		return
	VoiceManager.play_last_audio()


func _on_retry_recording() -> void:
	VoiceManager.stop_playback()
	VoiceManager.clear_last_audio()


func _on_audio_confirmed() -> void:
	if _active_npc == null:
		return
	if not VoiceManager.has_last_audio():
		_dialogue.add_npc_message("[color=red][Sin audio capturado][/color]")
		return
	VoiceManager.stop_playback()
	LLMClient.request_stt(VoiceManager.get_last_audio())


func _on_stt_completed(transcript: String) -> void:
	if _active_npc == null:
		return
	var text := transcript.strip_edges()
	if text.is_empty():
		_dialogue.add_npc_message("[color=yellow]No se detecto voz.[/color]")
		return
	# Mostrar panel de revisión de texto. El envío al NPC se dispara al confirmar.
	# La traducción al español se rellenará cuando el endpoint Gajito esté listo.
	_dialogue.show_text_review(text, "")


func _on_text_confirmed(transcript: String) -> void:
	if _active_npc == null:
		return
	_pending_player_text = transcript
	_dialogue.show_gajito_evaluating()
	LLMClient.request_gajito_evaluation(transcript)


func _on_retry_from_text() -> void:
	VoiceManager.stop_playback()
	VoiceManager.clear_last_audio()
	_pending_player_text = ""


func _on_gajito_evaluation_ready(passed: bool, _score: float, correction: String, tip: String, translation_es: String) -> void:
	if _active_npc == null:
		return
	if passed:
		var transcript := _pending_player_text
		_dialogue.add_player_message_with_translation(transcript, translation_es)
		LLMClient.request_npc(_active_npc.npc_id, transcript, _get_history(_active_npc.npc_id))
	else:
		# Texto rechazado por Gajito. Descartar audio y mostrar corrección.
		VoiceManager.clear_last_audio()
		_dialogue.show_gajito_correction(correction, tip)


func _on_gajito_evaluation_failed(error: String) -> void:
	_dialogue.add_npc_message("[color=red][Error Gajito: %s][/color]" % error)


func _on_gajito_correction_acknowledged() -> void:
	_pending_player_text = ""


func _on_pause_resumed() -> void:
	_player.enable_input(true)


func _on_exit_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		# Si hay diálogo abierto, DialogueUI maneja ESC (cierra el diálogo).
		# Si el menú de pausa ya está abierto, su propio handler procesa ESC.
		# Sólo abrimos el menú si nada captura el evento antes.
		if _dialogue.is_open() or _pause_menu.is_open():
			return
		_player.enable_input(false)
		_pause_menu.open()
		get_viewport().set_input_as_handled()


func _on_stt_failed(error: String) -> void:
	_dialogue.add_npc_message("[color=red][Error STT: %s][/color]" % error)


func _on_npc_response_ready(npc_id: String, text: String) -> void:
	if _active_npc == null or _active_npc.npc_id != npc_id:
		return
	var history := _get_history(npc_id)
	if not _pending_player_text.is_empty():
		history.append({"role": "user", "content": _pending_player_text})
		_pending_player_text = ""
	history.append({"role": "assistant", "content": text})
	_trim_history(history)
	_histories[npc_id] = history
	_dialogue.add_npc_message(text)


func _on_npc_request_failed(_npc_id: String, error: String) -> void:
	_dialogue.add_npc_message("[color=red][Error: %s][/color]" % error)


func _on_focus_label_changed(label: String) -> void:
	pass


func _on_focus_changed(focused: Node) -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("set_label_visible"):
			var is_this_npc := (focused != null) and ((focused == npc) or focused.is_ancestor_of(npc) or npc.is_ancestor_of(focused))
			npc.set_label_visible(is_this_npc)


func _hide_all_world_labels() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("set_label_visible"):
			npc.set_label_visible(false)


func _on_dialogue_requested(npc: Node) -> void:
	if _active_npc != null:
		return
	_active_npc = npc
	_pending_player_text = ""
	_hide_all_world_labels()
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


func _get_history(npc_id: String) -> Array:
	if not _histories.has(npc_id):
		_histories[npc_id] = []
	return _histories[npc_id]


func _trim_history(history: Array) -> void:
	while history.size() > HISTORY_MAX_MESSAGES:
		history.remove_at(0)
