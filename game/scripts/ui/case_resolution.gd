extends CanvasLayer

## Pantalla final de resolución del caso. Punto de no retorno — solo botón "Menú principal".
## Layer 25. Bloquea pausa, notebook, popup.

enum Mode { RESOLVED, FAILED }

const COLOR_STAMP_GOOD := Color(0.165, 0.353, 0.125)
const COLOR_STAMP_BAD := Color(0.416, 0.082, 0.125)
const COLOR_SESSION := Color(0.478, 0.416, 0.314)
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

const BODY_RESOLVED := "Barry Peel confiesa. El acuerdo del fideicomiso le daba motivo, la llave maestra acceso, y el encendedor de oro — identificado por Moni — lo coloca en la oficina de Cornelius.\n\nCaso cerrado."
const BODY_FAILED_WRONG := "Acusaste a la persona equivocada.\n\nEl verdadero culpable era Barry Peel — su encendedor en la oficina de Cornelius lo delataba. El caso queda sin resolver."
const BODY_FAILED_INSUFFICIENT := "No tenías pruebas suficientes para acusar a Barry.\n\nNecesitabas F1 (acuerdo del fideicomiso), F2 (llave maestra) y F3 (encendedor confirmado por Moni). Barry queda libre."

@onready var _stamp: Label = $Frame/VBox/Stamp
@onready var _title: Label = $Frame/VBox/Title
@onready var _subtitle: Label = $Frame/VBox/Subtitle
@onready var _body: Label = $Frame/VBox/Body
@onready var _evidence_label: Label = $Frame/VBox/EvidenceLabel
@onready var _session_label: Label = $Frame/VBox/SessionLabel
@onready var _session_field: LineEdit = $Frame/VBox/SessionField
@onready var _back_btn: Button = $Frame/VBox/BackBtn

var _is_open: bool = false


func _ready() -> void:
	layer = 25
	visible = false
	_back_btn.pressed.connect(_on_back_pressed)


func is_open() -> bool:
	return _is_open


func show_result(mode: int, accused: String, evidence: Array, reason: String = "") -> void:
	_is_open = true
	visible = true
	_cut_jazz()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var session: String = GameManager.session_id
	_session_field.text = session
	_session_label.modulate = COLOR_SESSION

	if mode == Mode.RESOLVED:
		_stamp.text = "✓"
		_stamp.modulate = COLOR_STAMP_GOOD
		_title.text = "CASO RESUELTO"
		_title.modulate = COLOR_STAMP_GOOD
		_subtitle.text = "Acusado: %s" % accused.capitalize()
		_body.text = BODY_RESOLVED
		_evidence_label.text = "Pruebas presentadas: %s" % ", ".join(_array_to_str(evidence))
		_evidence_label.visible = true
	else:
		_stamp.text = "✖"
		_stamp.modulate = COLOR_STAMP_BAD
		_title.text = "CASO FALLIDO"
		_title.modulate = COLOR_STAMP_BAD
		_subtitle.text = "Acusado: %s" % accused.capitalize() if not accused.is_empty() else "Sin acusación"
		_body.text = BODY_FAILED_WRONG if reason == GameManager.ACCUSATION_REASON_WRONG else BODY_FAILED_INSUFFICIENT
		_evidence_label.visible = false

	_back_btn.grab_focus()


func _array_to_str(arr: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item in arr:
		out.append(String(item))
	return out


func _cut_jazz() -> void:
	# Stub Art Bible §2.4 — silencio + lluvia. Sin asset de música aún.
	var idx := AudioServer.get_bus_index("Music")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, -80.0)
	print("[CaseResolution] jazz cut (stub)")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
