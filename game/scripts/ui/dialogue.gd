extends CanvasLayer

signal close_requested
## Emitido cuando el jugador empieza a grabar (mantiene V).
signal recording_started
## Emitido cuando el jugador suelta V. Backend captura audio pero no procesa STT aún.
signal recording_stopped
## Emitido cuando el jugador pulsa "Reproducir" en el panel de revisión.
signal playback_requested
## Emitido cuando el jugador pulsa "Enviar" — el backend debe correr STT ahora.
signal audio_confirmed
## Emitido cuando el jugador pulsa "Regrabar" — el backend debe descartar el audio.
signal retry_recording
## Emitido cuando el jugador confirma el texto transcrito antes de enviarlo al NPC.
signal text_confirmed(transcript: String)
## Emitido cuando el jugador descarta el texto transcrito y quiere regrabar.
signal retry_from_text
## Emitido cuando el jugador cierra el panel de corrección de Gajito.
signal gajito_correction_acknowledged
## Emitido cuando el jugador selecciona una pista para presentar al NPC.
signal clue_presentation_requested(clue_id: String)
## Emitido cuando el jugador presiona X para capturar un testimonio.
signal testimony_capture_requested(text: String, npc_id: String)

@export var chars_per_second: float = 40.0
## Imagen del retrato de Gajito que aparece en el panel de corrección.
## Asignar desde el inspector (FileSystem → arrastrar PNG/JPG).
@export var gajito_portrait: Texture2D = null

@onready var _panel: PanelContainer = $Panel
@onready var _npc_name: Label = $Panel/VBox/NpcName
@onready var _chat_log: RichTextLabel = $Panel/VBox/ChatBg/ChatLog
@onready var _status: Label = $Panel/VBox/StatusBg/Status
@onready var _audio_review: PanelContainer = $Panel/VBox/AudioReviewBg
@onready var _play_btn: Button = $Panel/VBox/AudioReviewBg/AudioReviewHBox/PlayBtn
@onready var _retry_btn: Button = $Panel/VBox/AudioReviewBg/AudioReviewHBox/RetryBtn
@onready var _send_btn: Button = $Panel/VBox/AudioReviewBg/AudioReviewHBox/SendBtn
@onready var _text_review: PanelContainer = $Panel/VBox/TextReviewBg
@onready var _english_label: Label = $Panel/VBox/TextReviewBg/TextReviewVBox/EnglishLabel
@onready var _spanish_label: Label = $Panel/VBox/TextReviewBg/TextReviewVBox/SpanishLabel
@onready var _text_retry_btn: Button = $Panel/VBox/TextReviewBg/TextReviewVBox/TextReviewHBox/TextRetryBtn
@onready var _text_confirm_btn: Button = $Panel/VBox/TextReviewBg/TextReviewVBox/TextReviewHBox/TextConfirmBtn
@onready var _gajito_correction: PanelContainer = $GajitoPanel
@onready var _gajito_portrait_rect: TextureRect = $GajitoPanel/GajitoHBox/Portrait
@onready var _correction_label: Label = $GajitoPanel/GajitoHBox/GajitoVBox/CorrectionLabel
@onready var _tip_label: Label = $GajitoPanel/GajitoHBox/GajitoVBox/TipLabel
@onready var _gajito_ack_btn: Button = $GajitoPanel/GajitoHBox/GajitoVBox/ButtonRow/GajitoAckBtn

const STATE_IDLE := "idle"
const STATE_RECORDING := "recording"
const STATE_AUDIO_REVIEW := "audio_review"
const STATE_TEXT_REVIEW := "text_review"
const STATE_GAJITO_EVAL := "gajito_eval"
const STATE_GAJITO_FAIL := "gajito_fail"
const STATE_PROCESSING := "processing"

var _npc: Node = null
var _state: String = STATE_IDLE
var _typewriter_active: bool = false
var _typewriter_progress: float = 0.0
var _pending_transcript: String = ""
var _evidence_picker_open: bool = false
var _evidence_panel: Control = null
var _evidence_list: VBoxContainer = null

var _capture_prompt: Label = null
var _capture_timer: Timer = null
var _last_npc_text: String = ""
var _last_npc_id: String = ""


func _ready() -> void:
	set_process(false)
	_play_btn.pressed.connect(_on_play_pressed)
	_retry_btn.pressed.connect(_on_retry_pressed)
	_send_btn.pressed.connect(_on_send_pressed)
	_text_retry_btn.pressed.connect(_on_text_retry_pressed)
	_text_confirm_btn.pressed.connect(_on_text_confirm_pressed)
	_gajito_ack_btn.pressed.connect(_on_gajito_ack_pressed)
	if gajito_portrait != null:
		_gajito_portrait_rect.texture = gajito_portrait
	GameManager.accessibility_font_size_changed.connect(_apply_font_size)
	_apply_font_size(GameManager.accessibility_font_size)
	_setup_evidence_picker()
	_setup_capture_prompt()


func _apply_font_size(size: int) -> void:
	_chat_log.add_theme_font_size_override("normal_font_size", size)
	_correction_label.add_theme_font_size_override("font_size", size)
	_tip_label.add_theme_font_size_override("font_size", size - 2)


func show_panel(npc: Node) -> void:
	_npc = npc
	_npc_name.text = npc.npc_name if "npc_name" in npc else "NPC"
	_chat_log.text = ""
	_chat_log.visible_characters = -1
	_typewriter_active = false
	set_process(false)
	_enter_idle()
	_panel.visible = true


func hide_panel() -> void:
	close_evidence_picker()
	_panel.visible = false
	_npc = null
	_state = STATE_IDLE
	_typewriter_active = false
	set_process(false)
	_audio_review.visible = false
	_text_review.visible = false
	_gajito_correction.visible = false
	_pending_transcript = ""


func is_open() -> bool:
	return _panel.visible


## Llamado por el backend cuando suelta V (audio capturado, listo para revisar).
func show_audio_review() -> void:
	_state = STATE_AUDIO_REVIEW
	_audio_review.visible = true
	set_status("Revisa tu grabación")


## Llamado por el backend al iniciar STT tras confirmación.
func show_stt_processing() -> void:
	_state = STATE_PROCESSING
	_audio_review.visible = false
	set_status("Transcribiendo...")


## Llamado por el backend cuando el STT termina. Muestra el texto en inglés
## y opcionalmente la traducción al español. El jugador confirma o regraba.
func show_text_review(english: String, spanish: String = "") -> void:
	_state = STATE_TEXT_REVIEW
	_pending_transcript = english
	_audio_review.visible = false
	_gajito_correction.visible = false
	_english_label.text = english
	if spanish.is_empty():
		_spanish_label.visible = false
		_spanish_label.text = ""
	else:
		_spanish_label.visible = true
		_spanish_label.text = "Gajito: " + spanish
	_text_review.visible = true
	set_status("¿Es correcto? Confirma o regraba")


## Llamado por el backend mientras Gajito evalúa gramática/pronunciación.
func show_gajito_evaluating() -> void:
	_state = STATE_GAJITO_EVAL
	_text_review.visible = false
	_audio_review.visible = false
	_gajito_correction.visible = false
	set_status("Gajito revisando tu inglés...")


## Llamado por el backend cuando Gajito reprueba el texto. El jugador acepta y regraba.
func show_gajito_correction(correction: String, tip: String) -> void:
	_state = STATE_GAJITO_FAIL
	_text_review.visible = false
	_audio_review.visible = false
	_correction_label.text = correction
	_tip_label.text = tip
	_tip_label.visible = not tip.is_empty()
	_gajito_correction.visible = true
	set_status("Inténtalo de nuevo")


## Variante de add_player_message que también muestra la traducción al español.
func add_player_message_with_translation(text: String, translation_es: String) -> void:
	_finish_typewriter()
	if translation_es.is_empty():
		_chat_log.append_text("\n[b][color=lightblue]Tú:[/color][/b] %s" % text)
	else:
		_chat_log.append_text(
			"\n[b][color=lightblue]Tú:[/color][/b] %s\n     [color=#8BC34A][i][ES] %s[/i][/color]" % [text, translation_es]
		)
	_chat_log.visible_characters = -1
	_state = STATE_PROCESSING
	set_status("Pensando...")


## Llamado por el backend cuando el STT termina (texto del jugador).
func add_player_message(text: String) -> void:
	_finish_typewriter()
	_chat_log.append_text("\n[b][color=lightblue]Tú:[/color][/b] %s" % text)
	_chat_log.visible_characters = -1
	_state = STATE_PROCESSING
	set_status("Pensando...")


## Llamado por el backend cuando llega respuesta del NPC (LLM).
func add_npc_message(text: String) -> void:
	_finish_typewriter()
	var start_count := _chat_log.get_total_character_count()
	_chat_log.visible_characters = start_count
	var name_text := _npc_name.text
	_chat_log.append_text("\n[b][color=orange]%s:[/color][/b] %s" % [name_text, text])
	_typewriter_progress = float(start_count)
	_typewriter_active = true
	set_status("Pensando...")
	set_process(true)
	_show_capture_prompt(text)


## Mensaje neutral del sistema (marcadores, stamps, capturas). No cambia estado.
func add_system_message(text: String) -> void:
	_finish_typewriter()
	_chat_log.append_text("\n[color=#9E9E9E][i]%s[/i][/color]" % text)
	_chat_log.visible_characters = -1


func set_status(text: String) -> void:
	_status.text = text


func _enter_idle() -> void:
	_state = STATE_IDLE
	_audio_review.visible = false
	_text_review.visible = false
	_gajito_correction.visible = false
	_pending_transcript = ""
	_set_idle_status()


func _set_idle_status() -> void:
	_status.text = "Mantén [V] para hablar — [Esc] para salir"


func _finish_typewriter() -> void:
	if _typewriter_active:
		_chat_log.visible_characters = -1
		_typewriter_active = false
		set_process(false)
		if _state == STATE_PROCESSING:
			_enter_idle()


func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	_typewriter_progress += chars_per_second * delta
	var total := _chat_log.get_total_character_count()
	var vc := int(_typewriter_progress)
	if vc >= total:
		_chat_log.visible_characters = -1
		_typewriter_active = false
		set_process(false)
		_enter_idle()
	else:
		_chat_log.visible_characters = vc


func _on_play_pressed() -> void:
	playback_requested.emit()


func _on_retry_pressed() -> void:
	retry_recording.emit()
	_enter_idle()


func _on_send_pressed() -> void:
	audio_confirmed.emit()
	show_stt_processing()


func _on_text_retry_pressed() -> void:
	retry_from_text.emit()
	_enter_idle()


func _on_text_confirm_pressed() -> void:
	var transcript := _pending_transcript
	_text_review.visible = false
	text_confirmed.emit(transcript)


func _on_gajito_ack_pressed() -> void:
	gajito_correction_acknowledged.emit()
	_enter_idle()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return

	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			close_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB and event.pressed:
			if _state == STATE_IDLE:
				toggle_evidence_picker()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_X and event.pressed:
			if _capture_prompt != null and _capture_prompt.visible:
				_capture_text()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_V:
			# V solo funciona en IDLE o durante RECORDING.
			if _state == STATE_IDLE and event.pressed:
				_state = STATE_RECORDING
				set_status("● Grabando... (suelta V)")
				recording_started.emit()
			elif _state == STATE_RECORDING and not event.pressed:
				# El backend mostrará el panel de revisión al recibir el audio.
				recording_stopped.emit()


# ── Evidence Picker (mini-notebook lateral durante diálogo) ────────


func toggle_evidence_picker() -> void:
	if _evidence_picker_open:
		close_evidence_picker()
	else:
		open_evidence_picker()


func open_evidence_picker() -> void:
	_evidence_picker_open = true
	_populate_evidence_picker()
	_evidence_panel.visible = true
	set_status("Selecciona una pista para mostrar — [TAB] para cerrar")


func close_evidence_picker() -> void:
	_evidence_picker_open = false
	_evidence_panel.visible = false
	if _state == STATE_IDLE:
		_set_idle_status()


func is_evidence_picker_open() -> bool:
	return _evidence_picker_open


const EVI_COLOR_PAPER := Color(0.961, 0.925, 0.784)
const EVI_COLOR_INK := Color(0.165, 0.102, 0.031)
const EVI_COLOR_GOOD := Color(0.165, 0.353, 0.125)
const EVI_COLOR_BAD := Color(0.416, 0.082, 0.125)
const EVI_COLOR_UNREVIEWED := Color(0.486, 0.4, 0.235)


func _setup_evidence_picker() -> void:
	_evidence_panel = Control.new()
	_evidence_panel.name = "EvidencePicker"
	_evidence_panel.visible = false
	_evidence_panel.anchor_left = 0.68
	_evidence_panel.anchor_right = 1.0
	_evidence_panel.anchor_top = 0.05
	_evidence_panel.anchor_bottom = 0.75
	_evidence_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_evidence_panel)

	var bg := ColorRect.new()
	bg.name = "PickerBG"
	bg.color = Color(0.02, 0.02, 0.05, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_evidence_panel.add_child(bg)

	var title := Label.new()
	title.name = "PickerTitle"
	title.text = "EVIDENCIAS"
	title.position = Vector2(12, 10)
	title.add_theme_color_override("font_color", EVI_COLOR_PAPER)
	title.add_theme_font_size_override("font_size", 15)
	_evidence_panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "PickerScroll"
	scroll.anchor_top = 0.08
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.anchor_left = 0.0
	_evidence_panel.add_child(scroll)

	_evidence_list = VBoxContainer.new()
	_evidence_list.name = "PickerList"
	_evidence_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_evidence_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_evidence_list)


func _populate_evidence_picker() -> void:
	for child in _evidence_list.get_children():
		child.queue_free()

	var clues := GameManager.get_all_clues()
	if clues.is_empty():
		var empty := Label.new()
		empty.text = "(sin pistas)"
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		empty.add_theme_font_size_override("font_size", 12)
		_evidence_list.add_child(empty)
		return

	for clue_id in clues:
		var clue: Dictionary = clues[clue_id]
		var state: String = String(clue.get("state", ""))
		var name: String = String(clue.get("name", clue_id))
		var glyph := _evi_glyph(state)
		var color := _evi_color(state)
		var clue_type: String = String(clue.get("type", "physical"))

		var btn := Button.new()
		var type_tag := " 📷"
		if clue_type == "testimony":
			type_tag = " 💬"
		btn.text = "[%s] %s — %s %s%s" % [clue_id, name, glyph, state, type_tag]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_color_override("font_color", EVI_COLOR_PAPER)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_focus_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("normal", _evi_btn_stylebox())
		btn.add_theme_stylebox_override("hover", _evi_btn_hover_stylebox())
		btn.add_theme_stylebox_override("focus", _evi_btn_hover_stylebox())

		btn.pressed.connect(_on_evidence_selected.bind(String(clue_id)))
		_evidence_list.add_child(btn)


func _on_evidence_selected(clue_id: String) -> void:
	clue_presentation_requested.emit(clue_id)
	close_evidence_picker()


func _evi_color(state: String) -> Color:
	match state:
		GameManager.STATE_GOOD:
			return EVI_COLOR_GOOD
		GameManager.STATE_BAD:
			return EVI_COLOR_BAD
		_:
			return EVI_COLOR_UNREVIEWED


func _evi_glyph(state: String) -> String:
	match state:
		GameManager.STATE_GOOD:
			return "✓"
		GameManager.STATE_BAD:
			return "✗"
		_:
			return "○"


func _evi_btn_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 4
	return sb


func _evi_btn_hover_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.15)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 4
	return sb


# ── Capture Testimony ─────────────────────────────────────────────


func _setup_capture_prompt() -> void:
	_capture_prompt = Label.new()
	_capture_prompt.name = "CapturePrompt"
	_capture_prompt.text = "[X] Agregar como evidencia"
	_capture_prompt.visible = false
	_capture_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_prompt.anchor_left = 0.35
	_capture_prompt.anchor_right = 0.65
	_capture_prompt.anchor_bottom = 1.0
	_capture_prompt.anchor_top = 0.92
	_capture_prompt.add_theme_color_override("font_color", Color("#8BC34A"))
	_capture_prompt.add_theme_font_size_override("font_size", 14)
	add_child(_capture_prompt)

	_capture_timer = Timer.new()
	_capture_timer.name = "CaptureTimer"
	_capture_timer.one_shot = true
	_capture_timer.timeout.connect(_hide_capture_prompt)
	add_child(_capture_timer)


func _show_capture_prompt(text: String) -> void:
	_last_npc_text = text
	_last_npc_id = _npc.npc_id if _npc != null else ""
	_capture_prompt.visible = true
	_capture_timer.start(4.0)


func _hide_capture_prompt() -> void:
	_capture_prompt.visible = false


func _capture_text() -> void:
	_capture_prompt.visible = false
	_capture_timer.stop()
	testimony_capture_requested.emit(_last_npc_text, _last_npc_id)
