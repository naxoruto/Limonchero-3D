extends Node3D

const FADE_DURATION := 0.6
const HISTORY_MAX_MESSAGES := 20

@onready var _interaction_system: Node = $Player/InteractionSystem
@onready var _dialogue: CanvasLayer = $DialogueUI
@onready var _player: CharacterBody3D = $Player
@onready var _fade: ColorRect = $FadeOverlay/FadeRect
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _notebook: CanvasLayer = $InventoryNotebook
@onready var _accusation: CanvasLayer = $AccusationDialog
@onready var _resolution: CanvasLayer = $CaseResolution
@onready var _inspect: CanvasLayer = $InspectOverlay

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _player_camera: Camera3D = null
var _active_npc: Node = null
var _histories: Dictionary = {}
var _pending_player_text: String = ""

# DEBUG: catalogo para smoke test del notebook. Borrar antes de release.
const _DEBUG_CLUES := [
	{"id": "F1", "name": "Acuerdo del Fideicomiso", "type": "physical", "state": "BUENA", "implica_a": "Barry"},
	{"id": "F2", "name": "Llave Maestra", "type": "physical", "state": "BUENA", "implica_a": "Barry"},
	{"id": "F3", "name": "Encendedor de Oro", "type": "physical", "state": "SIN_REVISAR", "implica_a": "?"},
	{"id": "F4", "name": "Maleta de Moni", "type": "physical", "state": "MALA", "implica_a": "Moni"},
	{"id": "F5", "name": "Sobre Quemado", "type": "physical", "state": "MALA", "implica_a": "Lola"},
]
var _debug_clue_index: int = 0
var _debug_last_clue_id: String = ""
const _DEBUG_STATE_CYCLE := ["SIN_REVISAR", "BUENA", "MALA"]


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
	_dialogue.clue_presentation_requested.connect(_on_clue_presentation_requested)
	_dialogue.testimony_capture_requested.connect(_on_testimony_capture_requested)
	LLMClient.gajito_evaluation_ready.connect(_on_gajito_evaluation_ready)
	LLMClient.gajito_evaluation_failed.connect(_on_gajito_evaluation_failed)
	VoiceManager.audio_captured.connect(_on_audio_captured)
	LLMClient.stt_completed.connect(_on_stt_completed)
	LLMClient.stt_failed.connect(_on_stt_failed)
	LLMClient.npc_response_ready.connect(_on_npc_response_ready)
	LLMClient.npc_request_failed.connect(_on_npc_request_failed)
	LLMClient.npc_evidence_response_ready.connect(_on_npc_evidence_response_ready)
	_fade.color = Color(0, 0, 0, 0)

	_pause_menu.bind_player(_player)
	_pause_menu.resumed.connect(_on_pause_resumed)
	_pause_menu.exit_to_main_menu.connect(_on_exit_to_main_menu)
	_pause_menu.open_notebook.connect(_on_open_notebook_from_pause)
	_notebook.opened.connect(_on_notebook_opened)
	_notebook.closed.connect(_on_notebook_closed)
	_notebook.inspect_requested.connect(_on_inspect_requested)
	_notebook.accuse_requested.connect(_on_accuse_requested)
	_accusation.opened.connect(_on_accusation_opened)
	_accusation.canceled.connect(_on_accusation_canceled)
	_accusation.accusation_confirmed.connect(_on_accusation_confirmed)
	GameManager.case_resolved.connect(_on_case_resolved)
	GameManager.case_failed.connect(_on_case_failed)
	_inspect.add_to_inventory_requested.connect(_on_inspect_add_to_inventory)
	_inspect.clue_validated.connect(_on_clue_validated)
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
		
	# Si detectó español, no darle la opción de confirmar el texto, que Gajito
	# lo castigue y rechace inmediatamente para que solo pueda reintentar.
	if LLMClient.get_last_language() == "es":
		_pending_player_text = text
		_dialogue.show_gajito_evaluating()
		LLMClient.request_gajito_evaluation(text)
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


func _on_clue_presentation_requested(clue_id: String) -> void:
	if _active_npc == null:
		return
	var clue := GameManager.get_clue(clue_id)
	if clue.is_empty():
		return
	var name := String(clue.get("name", clue_id))
	_dialogue.add_player_message("[Muestras: %s — %s]" % [clue_id, name])
	var history := _get_history(_active_npc.npc_id)
	LLMClient.request_npc_with_evidence(_active_npc.npc_id, clue, history)


func _on_testimony_capture_requested(text: String, npc_id: String) -> void:
	var testimony_id := _next_testimony_id()
	var npc_name: String = _active_npc.npc_name if _active_npc != null and "npc_name" in _active_npc else npc_id.capitalize()
	var data := {
		"name": "Declaracion de %s" % npc_name,
		"type": "testimony",
		"state": GameManager.STATE_UNREVIEWED,
		"description": "\"%s\"" % text,
		"source_npc": npc_id,
	}
	if GameManager.add_clue(testimony_id, data):
		_dialogue.add_system_message("[Testimonio capturado: %s]" % testimony_id)
		GajitoPopup.show_message("Declaracion de %s anadida como %s." % [npc_name, testimony_id], "low")
		HUDManager.show_inventory_notification(testimony_id)
	else:
		print("[EvidenceInterrogation] No se pudo capturar testimonio %s" % testimony_id)


var _testimony_counter: int = 0

func _next_testimony_id() -> String:
	_testimony_counter += 1
	return "T%d" % _testimony_counter


func _on_gajito_evaluation_ready(passed: bool, _score: float, correction: String, tip: String, translation_es: String) -> void:
	if _active_npc == null:
		return
	if passed:
		var transcript := _pending_player_text
		_dialogue.add_player_message_with_translation(transcript, translation_es)
		if not tip.strip_edges().is_empty():
			GajitoPopup.show_message(tip, "low")
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


# ── Inventory Notebook ────────────────────────────────────────────────────────

func _on_notebook_opened() -> void:
	_player.enable_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_notebook_closed() -> void:
	# No reactivar input si hay diálogo o pausa activos.
	if _dialogue.is_open() or _pause_menu.is_open():
		return
	_player.enable_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_inspect_requested(clue_id: String) -> void:
	_inspect.show_clue(clue_id)


func _on_inspect_add_to_inventory(clue_id: String) -> void:
	# Hook para futuro flujo de pickup desde el mundo. Por ahora no-op porque
	# si el inspect viene del notebook el clue ya está en inventario.
	print("[Inspect] add_to_inventory_requested: ", clue_id)


func _on_clue_validated(clue_id: String) -> void:
	var clue := GameManager.get_clue(clue_id)
	var name := String(clue.get("name", clue_id))
	GajitoPopup.show_message("Buena deduccion, Limonchero. '%s' ya es un hecho." % name, "low")


func _on_open_notebook_from_pause() -> void:
	_pause_menu.close()
	_notebook.open()


# ── Accusation flow ──────────────────────────────────────────────────────────

func _on_accuse_requested() -> void:
	_notebook.close()
	_accusation.open()


func _on_accusation_opened() -> void:
	_player.enable_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Bloquear UI ambiental durante acusación.
	GajitoPopup.set_blocked(true)
	_notebook.set_blocked(true)


func _on_accusation_canceled() -> void:
	GajitoPopup.set_blocked(false)
	_notebook.set_blocked(false)
	_player.enable_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_accusation_confirmed(accused: String, evidence: Array) -> void:
	GameManager.register_accusation(accused, evidence)
	# Mantener UI ambiental bloqueada — la pantalla de resolución (G4.2) tomará control.
	# GajitoPopup/notebook se desbloquean cuando G4.2 vuelva al menú principal.


func _on_case_resolved() -> void:
	GameManager.export_session_json()
	var attempt: Dictionary = _last_accusation_attempt()
	_resolution.show_result(
		_resolution.Mode.RESOLVED,
		String(attempt.get("accused", "")),
		attempt.get("evidence", []),
	)


func _on_case_failed(reason: String) -> void:
	GameManager.export_session_json()
	var attempt: Dictionary = _last_accusation_attempt()
	_resolution.show_result(
		_resolution.Mode.FAILED,
		String(attempt.get("accused", "")),
		attempt.get("evidence", []),
		reason,
	)


func _last_accusation_attempt() -> Dictionary:
	if GameManager.accusation_attempts.is_empty():
		return {}
	return GameManager.accusation_attempts[-1]


# DEBUG: smoke test pickup. Borrar antes de release.
func _debug_add_next_clue() -> void:
	if _debug_clue_index >= _DEBUG_CLUES.size():
		print("[Debug] No quedan clues en el catalogo de prueba.")
		return
	var entry: Dictionary = _DEBUG_CLUES[_debug_clue_index]
	if GameManager.add_clue(String(entry["id"]), entry):
		_debug_last_clue_id = String(entry["id"])
		print("[Debug] add_clue OK: ", _debug_last_clue_id, " state=", entry["state"])
		HUDManager.show_inventory_notification(String(entry["name"]))
	_debug_clue_index += 1


func _debug_cycle_last_clue_state() -> void:
	if _debug_last_clue_id.is_empty():
		print("[Debug] No hay clue para ciclar estado. Pulsa F11 primero.")
		return
	var current: String = String(GameManager.get_clue(_debug_last_clue_id).get("state", "SIN_REVISAR"))
	var idx := _DEBUG_STATE_CYCLE.find(current)
	var next: String = _DEBUG_STATE_CYCLE[(idx + 1) % _DEBUG_STATE_CYCLE.size()]
	GameManager.set_clue_state(_debug_last_clue_id, next)
	print("[Debug] set_clue_state ", _debug_last_clue_id, " -> ", next)


func _unhandled_input(event: InputEvent) -> void:
	# Resolución del caso: cualquier input se ignora salvo el botón "Menú principal".
	if _resolution.is_open():
		return

	# Tab toggle del notebook (acción Input "inventory_toggle").
	if event.is_action_pressed("inventory_toggle"):
		if _dialogue.is_open() or _pause_menu.is_open() or _accusation.is_open() or _inspect.is_open():
			return
		_notebook.toggle()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# DEBUG: imprime coord global del jugador + yaw. Borrar antes de release.
		if event.keycode == KEY_M:
			var p: Vector3 = _player.global_position
			var yaw_deg: float = rad_to_deg(_player.global_rotation.y)
			print("[POS] x=%.2f y=%.2f z=%.2f  yaw=%.1f°" % [p.x, p.y, p.z, yaw_deg])
			get_viewport().set_input_as_handled()
			return
		# DEBUG: smoke test GajitoPopup. Borrar antes de release.
		if event.keycode == KEY_F9:
			GajitoPopup.show_message("Prueba LOW: buen ingles, intenta mas natural.", "low")
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F10:
			GajitoPopup.show_message("Prueba HIGH: revisa el guardarropa.", "high")
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F11:
			if event.shift_pressed:
				_debug_cycle_last_clue_state()
			else:
				_debug_add_next_clue()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			# Durante acusación, ESC es ignorado (cancelación solo por botón).
			if _accusation.is_open():
				get_viewport().set_input_as_handled()
				return
			# Si inspect abierto, ESC lo cierra.
			if _inspect.is_open():
				_inspect.close()
				get_viewport().set_input_as_handled()
				return
			# Si notebook abierto, ESC lo cierra y no abre pausa.
			if _notebook.is_open():
				_notebook.close()
				get_viewport().set_input_as_handled()
				return
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


func _on_npc_evidence_response_ready(npc_id: String, clue_id: String, raw_text: String, cleaned_text: String) -> void:
	print("[EvidenceInterrogation] response NPC=%s clue=%s raw_len=%d cleaned_len=%d cleaned=%s" % [
		npc_id, clue_id, raw_text.length(), cleaned_text.length(), cleaned_text.left(120)
	])
	if cleaned_text.strip_edges().is_empty():
		cleaned_text = "..."
	_dialogue.add_npc_message(cleaned_text)
	_apply_evidence_stamp(npc_id, clue_id, raw_text)


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


# ── Evidence Interrogation — Auto-stamp ──────────────────────────────────────

const RECOGNITION_TABLE := {
	"moni": {"F3": "recognize_good", "F4": "self_confess_red"},
	"lola": {"F5": "self_confess_red"},
	"papolicia": {"F4": "dismiss_red", "F5": "dismiss_red"},
	"barry": {"F1": "recognize_good", "F2": "recognize_good", "F3": "recognize_good"},
	"gerry": {},
}

const STAMP_MESSAGES := {
	"recognize_good": "confirmo la pista %s. Marcada BUENA.",
	"self_confess_red": "con su reaccion, la pista %s queda descartada. Marcada MALA.",
	"dismiss_red": "descarta la pista %s. Marcada MALA.",
}


func _apply_evidence_stamp(npc_id: String, clue_id: String, raw_text: String) -> void:
	var reaction := LLMClient.parse_npc_reaction(raw_text)
	print("[EvidenceInterrogation] NPC=%s clue=%s reaction=%s raw=%s" % [npc_id, clue_id, reaction, raw_text.left(100)])

	if reaction == "ambiguous":
		reaction = _guess_reaction_from_text(raw_text, npc_id, clue_id)

	if reaction == "ambiguous":
		reaction = _expected_reaction(npc_id, clue_id)
		if reaction != "ambiguous":
			print("[EvidenceInterrogation] Fallback: using expected reaction '%s' for %s+%s" % [reaction, npc_id, clue_id])

	if reaction == "ambiguous":
		return

	var rule: String = RECOGNITION_TABLE.get(npc_id.to_lower(), {}).get(clue_id, "none")
	print("[EvidenceInterrogation] rule=%s for NPC=%s clue=%s" % [rule, npc_id, clue_id])
	if rule == "none":
		return

	var npc_name: String = _active_npc.npc_name if _active_npc != null and "npc_name" in _active_npc else npc_id.capitalize()

	match [rule, reaction]:
		["recognize_good", "recognize"]:
			GameManager.set_clue_state(clue_id, GameManager.STATE_GOOD)
			GajitoPopup.show_message("%s %s" % [npc_name, STAMP_MESSAGES["recognize_good"] % clue_id], "low")
			_dialogue.add_system_message("[%s → %s BUENA]" % [npc_name, clue_id])
		["self_confess_red", "confess"], ["dismiss_red", "deny"]:
			GameManager.set_clue_state(clue_id, GameManager.STATE_BAD)
			GajitoPopup.show_message("%s %s" % [npc_name, STAMP_MESSAGES["self_confess_red"] % clue_id], "low")
			_dialogue.add_system_message("[%s → %s MALA]" % [npc_name, clue_id])
		["self_confess_red", "recognize"]:
			GameManager.set_clue_state(clue_id, GameManager.STATE_BAD)
			GajitoPopup.show_message("%s %s" % [npc_name, STAMP_MESSAGES["self_confess_red"] % clue_id], "low")
			_dialogue.add_system_message("[%s → %s MALA]" % [npc_name, clue_id])
		_:
			pass


func _guess_reaction_from_text(text: String, _npc_id: String, _clue_id: String) -> String:
	var lower := text.to_lower()
	if lower.contains("recognize") or lower.contains("that's mine") or lower.contains("i know this") or lower.contains("i'd know it"):
		return "recognize"
	if lower.contains("confess") or lower.contains("i did it") or lower.contains("i killed") or lower.contains("that's... mine"):
		return "confess"
	if lower.contains("deny") or lower.contains("not mine") or lower.contains("wasn't me") or lower.contains("never seen"):
		return "deny"
	if lower.contains("evade") or lower.contains("i don't know") or lower.contains("can't say"):
		return "evade"
	return "ambiguous"


func _expected_reaction(npc_id: String, clue_id: String) -> String:
	var rule: String = RECOGNITION_TABLE.get(npc_id.to_lower(), {}).get(clue_id, "none")
	match rule:
		"recognize_good":
			return "recognize"
		"self_confess_red":
			return "confess"
		"dismiss_red":
			return "deny"
		_:
			return "ambiguous"
