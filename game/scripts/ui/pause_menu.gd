extends CanvasLayer

signal resumed
signal exit_to_main_menu
signal open_notebook

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "general"

const FOV_DEFAULT := 75.0
const FOV_MIN := 70.0
const FOV_MAX := 110.0
const MOUSE_SENS_DEFAULT := 0.002
const MOUSE_SENS_MIN := 0.0005
const MOUSE_SENS_MAX := 0.01
const FONT_SIZE_DEFAULT := 16
const FONT_SIZE_MIN := 12
const FONT_SIZE_MAX := 24
const VOL_DEFAULT := 0.0
const VOL_MIN := -40.0
const VOL_MAX := 6.0

enum SubPanel { MAIN, SETTINGS, EXIT_CONFIRM }

@onready var _bg: ColorRect = $Background
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _settings_panel: PanelContainer = $SettingsPanel
@onready var _exit_panel: PanelContainer = $ExitConfirmPanel

@onready var _resume_btn: Button = $MainPanel/MainVBox/ResumeBtn
@onready var _notes_btn: Button = $MainPanel/MainVBox/NotesBtn
@onready var _settings_btn: Button = $MainPanel/MainVBox/SettingsBtn
@onready var _exit_btn: Button = $MainPanel/MainVBox/ExitBtn

@onready var _fov_slider: HSlider = $SettingsPanel/SettingsVBox/FovRow/FovSlider
@onready var _fov_value: Label = $SettingsPanel/SettingsVBox/FovRow/FovValue
@onready var _mouse_slider: HSlider = $SettingsPanel/SettingsVBox/MouseRow/MouseSlider
@onready var _mouse_value: Label = $SettingsPanel/SettingsVBox/MouseRow/MouseValue
@onready var _font_slider: HSlider = $SettingsPanel/SettingsVBox/FontRow/FontSlider
@onready var _font_value: Label = $SettingsPanel/SettingsVBox/FontRow/FontValue
@onready var _vol_master_slider: HSlider = $SettingsPanel/SettingsVBox/VolMasterRow/VolMasterSlider
@onready var _vol_master_value: Label = $SettingsPanel/SettingsVBox/VolMasterRow/VolMasterValue
@onready var _vol_sfx_slider: HSlider = $SettingsPanel/SettingsVBox/VolSfxRow/VolSfxSlider
@onready var _vol_sfx_value: Label = $SettingsPanel/SettingsVBox/VolSfxRow/VolSfxValue
@onready var _vol_mic_slider: HSlider = $SettingsPanel/SettingsVBox/VolMicRow/VolMicSlider
@onready var _vol_mic_value: Label = $SettingsPanel/SettingsVBox/VolMicRow/VolMicValue
@onready var _settings_back_btn: Button = $SettingsPanel/SettingsVBox/BackBtn

@onready var _exit_yes_btn: Button = $ExitConfirmPanel/ExitVBox/ButtonRow/ExitYesBtn
@onready var _exit_cancel_btn: Button = $ExitConfirmPanel/ExitVBox/ButtonRow/ExitCancelBtn

var _is_open: bool = false
var _current_sub: SubPanel = SubPanel.MAIN
var _player: Node = null
var _camera: Camera3D = null

# Settings cache
var _settings := {
	"fov": FOV_DEFAULT,
	"mouse_sensitivity": MOUSE_SENS_DEFAULT,
	"font_size": FONT_SIZE_DEFAULT,
	"vol_master": VOL_DEFAULT,
	"vol_sfx": VOL_DEFAULT,
	"vol_mic": VOL_DEFAULT,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_load_settings()
	_wire_buttons()
	_wire_sliders()
	_apply_settings_to_runtime()


func bind_player(player: Node) -> void:
	_player = player
	if player != null:
		var cam := player.get_node_or_null("Camera3D")
		if cam is Camera3D:
			_camera = cam
	_apply_settings_to_runtime()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_show_sub(SubPanel.MAIN)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_btn.grab_focus()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _wire_buttons() -> void:
	_resume_btn.pressed.connect(close)
	_notes_btn.pressed.connect(_on_notes_pressed)
	_notes_btn.disabled = true
	_notes_btn.tooltip_text = "Próximamente (G3.1)"
	_settings_btn.pressed.connect(func(): _show_sub(SubPanel.SETTINGS))
	_exit_btn.pressed.connect(func(): _show_sub(SubPanel.EXIT_CONFIRM))
	_settings_back_btn.pressed.connect(func(): _show_sub(SubPanel.MAIN))
	_exit_yes_btn.pressed.connect(_on_exit_confirmed)
	_exit_cancel_btn.pressed.connect(func(): _show_sub(SubPanel.MAIN))


func _wire_sliders() -> void:
	_fov_slider.min_value = FOV_MIN
	_fov_slider.max_value = FOV_MAX
	_fov_slider.step = 1.0
	_fov_slider.value = _settings["fov"]
	_fov_slider.value_changed.connect(_on_fov_changed)

	_mouse_slider.min_value = MOUSE_SENS_MIN
	_mouse_slider.max_value = MOUSE_SENS_MAX
	_mouse_slider.step = 0.0001
	_mouse_slider.value = _settings["mouse_sensitivity"]
	_mouse_slider.value_changed.connect(_on_mouse_changed)

	_font_slider.min_value = FONT_SIZE_MIN
	_font_slider.max_value = FONT_SIZE_MAX
	_font_slider.step = 1.0
	_font_slider.value = _settings["font_size"]
	_font_slider.value_changed.connect(_on_font_changed)

	_vol_master_slider.min_value = VOL_MIN
	_vol_master_slider.max_value = VOL_MAX
	_vol_master_slider.step = 0.5
	_vol_master_slider.value = _settings["vol_master"]
	_vol_master_slider.value_changed.connect(_on_vol_master_changed)

	_vol_sfx_slider.min_value = VOL_MIN
	_vol_sfx_slider.max_value = VOL_MAX
	_vol_sfx_slider.step = 0.5
	_vol_sfx_slider.value = _settings["vol_sfx"]
	_vol_sfx_slider.value_changed.connect(_on_vol_sfx_changed)

	_vol_mic_slider.min_value = VOL_MIN
	_vol_mic_slider.max_value = VOL_MAX
	_vol_mic_slider.step = 0.5
	_vol_mic_slider.value = _settings["vol_mic"]
	_vol_mic_slider.value_changed.connect(_on_vol_mic_changed)

	_refresh_slider_labels()


func _refresh_slider_labels() -> void:
	_fov_value.text = "%d°" % int(_settings["fov"])
	_mouse_value.text = "%.4f" % float(_settings["mouse_sensitivity"])
	_font_value.text = "%dpt" % int(_settings["font_size"])
	_vol_master_value.text = "%.1f dB" % float(_settings["vol_master"])
	_vol_sfx_value.text = "%.1f dB" % float(_settings["vol_sfx"])
	_vol_mic_value.text = "%.1f dB" % float(_settings["vol_mic"])


func _show_sub(sub: SubPanel) -> void:
	_current_sub = sub
	_main_panel.visible = (sub == SubPanel.MAIN)
	_settings_panel.visible = (sub == SubPanel.SETTINGS)
	_exit_panel.visible = (sub == SubPanel.EXIT_CONFIRM)


# ── Slider handlers ─────────────────────────────────────────────────

func _on_fov_changed(value: float) -> void:
	_settings["fov"] = value
	_apply_fov(value)
	_refresh_slider_labels()
	_save_settings()


func _on_mouse_changed(value: float) -> void:
	_settings["mouse_sensitivity"] = value
	_apply_mouse_sensitivity(value)
	_refresh_slider_labels()
	_save_settings()


func _on_font_changed(value: float) -> void:
	_settings["font_size"] = int(value)
	_refresh_slider_labels()
	_save_settings()


func _on_vol_master_changed(value: float) -> void:
	_settings["vol_master"] = value
	_apply_bus_volume("Master", value)
	_refresh_slider_labels()
	_save_settings()


func _on_vol_sfx_changed(value: float) -> void:
	_settings["vol_sfx"] = value
	_apply_bus_volume("SFX", value)
	_refresh_slider_labels()
	_save_settings()


func _on_vol_mic_changed(value: float) -> void:
	_settings["vol_mic"] = value
	_apply_bus_volume("Mic", value)
	_refresh_slider_labels()
	_save_settings()


# ── Apply settings ──────────────────────────────────────────────────

func _apply_settings_to_runtime() -> void:
	_apply_fov(float(_settings["fov"]))
	_apply_mouse_sensitivity(float(_settings["mouse_sensitivity"]))
	_apply_bus_volume("Master", float(_settings["vol_master"]))
	_apply_bus_volume("SFX", float(_settings["vol_sfx"]))
	_apply_bus_volume("Mic", float(_settings["vol_mic"]))


func _apply_fov(value: float) -> void:
	if _camera != null:
		_camera.fov = value


func _apply_mouse_sensitivity(value: float) -> void:
	if _player != null and _player.has_method("set_mouse_sensitivity"):
		_player.set_mouse_sensitivity(value)


func _apply_bus_volume(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, db)


# ── Persistence ─────────────────────────────────────────────────────

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	for key in _settings.keys():
		var v = cfg.get_value(SETTINGS_SECTION, key, _settings[key])
		_settings[key] = v


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _settings.keys():
		cfg.set_value(SETTINGS_SECTION, key, _settings[key])
	cfg.save(SETTINGS_PATH)


# ── Exit ────────────────────────────────────────────────────────────

func _on_notes_pressed() -> void:
	open_notebook.emit()


func _on_exit_confirmed() -> void:
	# Reanudar el árbol antes de cambiar de escena para evitar nodos pausados huérfanos.
	get_tree().paused = false
	exit_to_main_menu.emit()


# ── Input ───────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _current_sub == SubPanel.MAIN:
			close()
		else:
			_show_sub(SubPanel.MAIN)
		get_viewport().set_input_as_handled()
