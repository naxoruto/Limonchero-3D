extends CanvasLayer

## Popup ambiental no-bloqueante para mensajes de Gajito (tips, anti-stall, refuerzos).
## Canal B del flujo de Gajito. Canal A (corrección bloqueante con ack) vive en DialogueUI.
##
## API:
##   GajitoPopup.show_message(text, severity, duration=-1)  # severity: "high" | "low" | "hint"
##   GajitoPopup.dismiss()
##   GajitoPopup.clear_queue()
##   GajitoPopup.set_blocked(bool)  # Para árbol de acusación (G4.1)

const FADE_IN := 0.2
const FADE_OUT := 0.5
const DEFAULT_DURATION_HIGH := 5.0
const DEFAULT_DURATION_LOW := 3.0
const DEFAULT_DURATION_HINT := 3.0
const MAX_QUEUE := 3

const SEVERITY_PRIORITY := {"high": 2, "low": 1, "hint": 0}

@onready var _panel: PanelContainer = $Panel
@onready var _header: Label = $Panel/VBox/Header
@onready var _body: Label = $Panel/VBox/Body

var _queue: Array[Dictionary] = []
var _showing: bool = false
var _blocked: bool = false
var _current_severity: String = ""
var _dismiss_timer: Timer = null
var _tween: Tween = null


func _ready() -> void:
	layer = 15
	_panel.modulate.a = 0.0
	_panel.visible = false
	_dismiss_timer = Timer.new()
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(_on_dismiss_timeout)
	add_child(_dismiss_timer)


func show_message(text: String, severity: String = "low", duration: float = -1.0) -> void:
	if _blocked:
		return
	if text.strip_edges().is_empty():
		return
	if not SEVERITY_PRIORITY.has(severity):
		severity = "low"

	var dur := duration
	if dur < 0.0:
		dur = _default_duration_for(severity)

	var msg := {"text": text, "severity": severity, "duration": dur}

	# High reemplaza mensaje actual de menor prioridad.
	if _showing and severity == "high" and SEVERITY_PRIORITY[_current_severity] < SEVERITY_PRIORITY["high"]:
		_queue.clear()
		_kill_tween()
		_dismiss_timer.stop()
		_show_now(msg)
		return

	# Encolar con tope. Drop oldest si lleno.
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
	_queue.append(msg)

	if not _showing:
		_advance_queue()


func dismiss() -> void:
	if not _showing:
		return
	_dismiss_timer.stop()
	_fade_out_then(func():
		_showing = false
		_current_severity = ""
		_advance_queue()
	)


func clear_queue() -> void:
	_queue.clear()


func set_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		clear_queue()
		dismiss()


func _default_duration_for(severity: String) -> float:
	match severity:
		"high":
			return DEFAULT_DURATION_HIGH
		"low":
			return DEFAULT_DURATION_LOW
		_:
			return DEFAULT_DURATION_HINT


func _advance_queue() -> void:
	if _queue.is_empty():
		return
	var msg: Dictionary = _queue.pop_front()
	_show_now(msg)


func _show_now(msg: Dictionary) -> void:
	_header.text = "Gajito"
	_body.text = msg["text"]
	_current_severity = msg["severity"]
	_showing = true
	_panel.visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN)
	_tween.tween_callback(func():
		_dismiss_timer.start(msg["duration"])
	)


func _on_dismiss_timeout() -> void:
	_fade_out_then(func():
		_showing = false
		_current_severity = ""
		_advance_queue()
	)


func _fade_out_then(callback: Callable) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func():
		_panel.visible = false
		callback.call()
	)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
