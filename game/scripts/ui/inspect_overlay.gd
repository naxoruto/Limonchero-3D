extends CanvasLayer

## Overlay de inspección de evidencia. Layer 17 (above notebook 14, popup 15, accusation 16).
## MVP: placeholder 2D (sin modelos 3D aún). Drag rota, wheel hace zoom.
##
## API:
##   show_clue(clue_id: String)
##   close()
##   is_open() -> bool
##
## Signals:
##   opened(), closed(), add_to_inventory_requested(clue_id)

signal opened()
signal closed()
signal add_to_inventory_requested(clue_id: String)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5
const ZOOM_STEP := 0.1
const ROTATE_SENSITIVITY := 0.6  # grados por pixel
const PULSE_HZ := 0.5

@onready var _bg: ColorRect = $BG
@onready var _frame: PanelContainer = $Frame
@onready var _header_title: Label = $Frame/VBox/Header/Title
@onready var _header_state: Label = $Frame/VBox/Header/StateStamp
@onready var _close_btn: Button = $Frame/VBox/Header/CloseBtn
@onready var _viewport_area: Control = $Frame/VBox/ViewportArea
@onready var _photo: ColorRect = $Frame/VBox/ViewportArea/Pivot/Photo
@onready var _pivot: Control = $Frame/VBox/ViewportArea/Pivot
@onready var _description: Label = $Frame/VBox/Description
@onready var _add_btn: Button = $Frame/VBox/Actions/AddBtn

var _is_open: bool = false
var _current_clue_id: String = ""
var _dragging: bool = false
var _zoom: float = 1.0
var _rotation_deg: float = 0.0
var _pulse_time: float = 0.0


func _ready() -> void:
	layer = 17
	visible = false
	_close_btn.pressed.connect(close)
	_add_btn.pressed.connect(_on_add_pressed)
	_viewport_area.gui_input.connect(_on_viewport_gui_input)
	_bg.gui_input.connect(_on_bg_gui_input)
	GameManager.accessibility_font_size_changed.connect(_apply_font_size)
	_apply_font_size(GameManager.accessibility_font_size)
	set_process(false)


func _apply_font_size(size: int) -> void:
	_description.add_theme_font_size_override("font_size", size)


func is_open() -> bool:
	return _is_open


func show_clue(clue_id: String) -> void:
	var clue: Dictionary = GameManager.get_clue(clue_id)
	if clue.is_empty():
		push_warning("InspectOverlay.show_clue: clue '%s' no existe" % clue_id)
		return
	_current_clue_id = clue_id
	_is_open = true
	_zoom = 1.0
	_rotation_deg = 0.0
	_pulse_time = 0.0
	_apply_transform()

	_header_title.text = "[%s] %s" % [clue_id, String(clue.get("name", clue_id))]
	var state: String = String(clue.get("state", GameManager.STATE_UNREVIEWED))
	_header_state.text = "%s %s" % [_state_glyph(state), state]
	_header_state.modulate = _state_color(state)
	_description.text = _build_description(clue)
	_photo.color = _color_for_clue(clue_id)

	# Si ya está en inventario (siempre lo está cuando se invoca desde notebook),
	# el botón muestra disabled.
	var in_inv := GameManager.has_clue(clue_id)
	_add_btn.disabled = in_inv
	_add_btn.text = "Ya en inventario" if in_inv else "Añadir al inventario"

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(true)
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	# Rim light pulsante en el sello de estado (Art Bible §2.3).
	_pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(_pulse_time * TAU * PULSE_HZ)
	_header_state.modulate.a = 0.5 + 0.5 * pulse


func _apply_transform() -> void:
	_photo.pivot_offset = _photo.size / 2.0
	_photo.scale = Vector2.ONE * _zoom
	_photo.rotation_degrees = _rotation_deg


func _build_description(clue: Dictionary) -> String:
	var parts := PackedStringArray()
	var implica = clue.get("implica_a", "")
	if not String(implica).is_empty():
		parts.append("Implica a: %s" % implica)
	var desc = clue.get("description", "")
	if not String(desc).is_empty():
		parts.append(String(desc))
	if parts.is_empty():
		parts.append("Sin descripción detallada.")
	return "\n".join(parts)


func _state_color(state: String) -> Color:
	match state:
		GameManager.STATE_GOOD:
			return Color(0.165, 0.353, 0.125)
		GameManager.STATE_BAD:
			return Color(0.416, 0.082, 0.125)
		_:
			return Color(0.486, 0.4, 0.235)


func _state_glyph(state: String) -> String:
	match state:
		GameManager.STATE_GOOD:
			return "✓"
		GameManager.STATE_BAD:
			return "✗"
		_:
			return "○"


func _color_for_clue(clue_id: String) -> Color:
	# Color determinístico del placeholder a partir del ID.
	var h := hash(clue_id)
	var r := float((h & 0xFF)) / 255.0
	var g := float(((h >> 8) & 0xFF)) / 255.0
	var b := float(((h >> 16) & 0xFF)) / 255.0
	return Color(0.3 + 0.5 * r, 0.3 + 0.5 * g, 0.3 + 0.5 * b)


# ── Input ────────────────────────────────────────────────────────────────────

func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			_apply_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			_apply_transform()
	elif event is InputEventMouseMotion and _dragging:
		_rotation_deg += event.relative.x * ROTATE_SENSITIVITY
		_apply_transform()


func _on_bg_gui_input(event: InputEvent) -> void:
	# Click fuera del frame también cierra.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()


func _on_add_pressed() -> void:
	if _current_clue_id.is_empty():
		return
	add_to_inventory_requested.emit(_current_clue_id)
