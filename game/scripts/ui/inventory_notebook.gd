extends CanvasLayer

## Inventario tipo libreta detective. Se abre con Tab o desde pause.
## Layer 14: above HUD (10), below GajitoPopup (15) y pause (20).
##
## API:
##   open() / close() / toggle()
##   is_open() -> bool
##   set_blocked(bool)  # Para acusación (G4.1): impide abrir
##
## Signals:
##   opened, closed, inspect_requested(clue_id)

signal opened()
signal closed()
signal inspect_requested(clue_id: String)
signal accuse_requested()

const COLOR_PAPER := Color(0.961, 0.925, 0.784)
const COLOR_LEATHER := Color(0.239, 0.145, 0.063)
const COLOR_INK := Color(0.165, 0.102, 0.031)
const COLOR_FRAME := Color(0.941, 0.929, 0.878)
const COLOR_EMPTY_BORDER := Color(0.627, 0.565, 0.439)
const COLOR_STAMP_GOOD := Color(0.165, 0.353, 0.125)
const COLOR_STAMP_BAD := Color(0.416, 0.082, 0.125)
const COLOR_STAMP_UNREVIEWED := Color(0.486, 0.4, 0.235)

const SLOTS_PER_COLUMN := 4
const TOTAL_SLOTS := 8

@onready var _bg: ColorRect = $BG
@onready var _hechos_grid: GridContainer = $Frame/Pages/Body/Columns/HechosColumn/HechosGrid
@onready var _sospechas_grid: GridContainer = $Frame/Pages/Body/Columns/SospechasColumn/SospechasGrid
@onready var _accuse_btn: Button = $Frame/Pages/Body/Footer/AccuseBtn

var _is_open: bool = false
var _blocked: bool = false
var _name_font_size: int = 11


func _ready() -> void:
	layer = 14
	visible = false
	GameManager.clue_added.connect(_on_clue_changed)
	GameManager.clue_state_changed.connect(_on_clue_state_changed)
	GameManager.accessibility_font_size_changed.connect(_on_font_size_changed)
	_name_font_size = clamp(GameManager.accessibility_font_size - 5, 9, 18)
	_bg.gui_input.connect(_on_bg_gui_input)
	_accuse_btn.pressed.connect(_on_accuse_pressed)
	refresh()


func _on_font_size_changed(size: int) -> void:
	_name_font_size = clamp(size - 5, 9, 18)
	if _is_open:
		refresh()


func is_open() -> bool:
	return _is_open


func set_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked and _is_open:
		close()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open or _blocked:
		return
	_is_open = true
	visible = true
	refresh()
	_focus_first_slot()
	opened.emit()


func _focus_first_slot() -> void:
	for child in _hechos_grid.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL:
			(child as Control).grab_focus()
			return
	for child in _sospechas_grid.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL:
			(child as Control).grab_focus()
			return
	_accuse_btn.grab_focus()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func refresh() -> void:
	for child in _hechos_grid.get_children():
		child.queue_free()
	for child in _sospechas_grid.get_children():
		child.queue_free()

	var clues := GameManager.get_all_clues()
	var hechos: Array = []
	var sospechas: Array = []
	for clue_id in clues:
		var clue: Dictionary = clues[clue_id]
		if clue.get("type", "physical") != "physical":
			continue
		if clue.get("state", "") == GameManager.STATE_GOOD:
			hechos.append(clue)
		else:
			sospechas.append(clue)

	_populate_column(_hechos_grid, hechos)
	_populate_column(_sospechas_grid, sospechas)
	_accuse_btn.disabled = hechos.is_empty()


func _populate_column(grid: GridContainer, clues: Array) -> void:
	var count := mini(clues.size(), SLOTS_PER_COLUMN)
	for i in count:
		grid.add_child(_make_slot(clues[i]))
	for i in range(count, SLOTS_PER_COLUMN):
		grid.add_child(_make_empty_slot())


func _make_slot(clue: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(180, 140)
	slot.add_theme_stylebox_override("panel", _slot_stylebox(false))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.focus_mode = Control.FOCUS_ALL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	slot.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var code := Label.new()
	code.text = String(clue.get("id", "?"))
	code.add_theme_color_override("font_color", COLOR_INK)
	code.add_theme_font_size_override("font_size", 14)
	header.add_child(code)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var stamp := Label.new()
	var state: String = clue.get("state", GameManager.STATE_UNREVIEWED)
	stamp.text = "%s %s" % [_stamp_glyph(state), state]
	stamp.add_theme_color_override("font_color", _stamp_color(state))
	stamp.add_theme_font_size_override("font_size", 10)
	header.add_child(stamp)

	var photo := ColorRect.new()
	photo.custom_minimum_size = Vector2(160, 70)
	photo.color = Color(0.78, 0.74, 0.6)
	vbox.add_child(photo)

	var name_label := Label.new()
	name_label.text = String(clue.get("name", clue.get("id", "?")))
	name_label.add_theme_color_override("font_color", COLOR_INK)
	name_label.add_theme_font_size_override("font_size", _name_font_size)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(name_label)

	var clue_id := String(clue.get("id", ""))
	slot.gui_input.connect(_on_slot_gui_input.bind(clue_id))
	return slot


func _make_empty_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(180, 140)
	slot.add_theme_stylebox_override("panel", _slot_stylebox(true))
	slot.mouse_filter = Control.MOUSE_FILTER_PASS

	var center := CenterContainer.new()
	slot.add_child(center)

	var label := Label.new()
	label.text = "— vacío —"
	label.add_theme_color_override("font_color", COLOR_EMPTY_BORDER)
	label.add_theme_font_size_override("font_size", 11)
	center.add_child(label)
	return slot


func _slot_stylebox(empty: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if empty:
		sb.bg_color = Color(0.961, 0.925, 0.784, 0.4)
		sb.set_border_width_all(1)
		sb.border_color = COLOR_EMPTY_BORDER
	else:
		sb.bg_color = COLOR_FRAME
		sb.set_border_width_all(2)
		sb.border_color = COLOR_INK
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	return sb


func _stamp_color(state: String) -> Color:
	match state:
		GameManager.STATE_GOOD:
			return COLOR_STAMP_GOOD
		GameManager.STATE_BAD:
			return COLOR_STAMP_BAD
		_:
			return COLOR_STAMP_UNREVIEWED


func _stamp_glyph(state: String) -> String:
	match state:
		GameManager.STATE_GOOD:
			return "✓"
		GameManager.STATE_BAD:
			return "✗"
		_:
			return "○"


func _on_clue_changed(_clue_id: String) -> void:
	if _is_open:
		refresh()


func _on_clue_state_changed(_clue_id: String, _state: String) -> void:
	if _is_open:
		refresh()


func _on_slot_gui_input(event: InputEvent, clue_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		inspect_requested.emit(clue_id)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_KP_ENTER:
			inspect_requested.emit(clue_id)
			get_viewport().set_input_as_handled()


func _on_bg_gui_input(event: InputEvent) -> void:
	# Click fuera del frame cierra. El frame captura sus propios eventos.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()


func _on_accuse_pressed() -> void:
	accuse_requested.emit()
