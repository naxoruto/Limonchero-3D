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
		if event.keycode == KEY_V:
			# V solo funciona en IDLE o durante RECORDING.
			if _state == STATE_IDLE and event.pressed:
				_state = STATE_RECORDING
				set_status("● Grabando... (suelta V)")
				recording_started.emit()
			elif _state == STATE_RECORDING and not event.pressed:
				# El backend mostrará el panel de revisión al recibir el audio.
				recording_stopped.emit()
