extends Control

const BACKEND_HEALTH_URL := "http://localhost:8000/health"
const HEALTH_TIMEOUT_SEC := 2.0
const MAX_RETRIES := 3
const NEXT_SCENE := "res://scenes/level/el_agave_y_la_luna_main.tscn"

@onready var title: Label = $CenterContainer/VBox/Title
@onready var subtitle: Label = $CenterContainer/VBox/Subtitle
@onready var session_input: LineEdit = $CenterContainer/VBox/SessionInput
@onready var start_btn: Button = $CenterContainer/VBox/StartButton
@onready var status_icon: Label = $CenterContainer/VBox/StatusHBox/StatusIcon
@onready var status_text: Label = $CenterContainer/VBox/StatusHBox/StatusText
@onready var exit_btn: Button = $CenterContainer/VBox/ExitButton
@onready var retry_link: Label = $CenterContainer/VBox/StatusHBox/RetryLink

var _retries := 0
var _health_ok := false


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	session_input.text_submitted.connect(_on_session_input_text_submitted)
	retry_link.gui_input.connect(_on_retry_gui_input)
	_set_ui_locked(true)
	_set_status("checking", "Verificando servidor...")
	_check_backend()


func _set_ui_locked(locked: bool) -> void:
	start_btn.disabled = locked or not _health_ok
	session_input.editable = locked


func _set_status(state: String, text: String) -> void:
	match state:
		"checking":
			status_icon.text = "◌"
			status_icon.modulate = Color("#D4A030")
			retry_link.visible = false
		"ok":
			status_icon.text = "●"
			status_icon.modulate = Color("#2A5A20")
			retry_link.visible = false
		"fail":
			status_icon.text = "✖"
			status_icon.modulate = Color("#6A1520")
			retry_link.visible = true
	status_text.text = text


func _check_backend() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = HEALTH_TIMEOUT_SEC
	http.request_completed.connect(_on_health_response.bind(http))
	http.request(BACKEND_HEALTH_URL)


func _on_health_response(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_health_ok = true
		_set_ui_locked(false)
		_set_status("ok", "Backend conectado")
		start_btn.disabled = false
		start_btn.grab_focus()
	else:
		_retries += 1
		if _retries < MAX_RETRIES:
			_set_status("checking", "Reintentando (%d/%d)..." % [_retries + 1, MAX_RETRIES])
			await get_tree().create_timer(1.0).timeout
			_check_backend()
		else:
			_health_ok = false
			_set_ui_locked(false)
			_set_status("fail", "Servidor no disponible — inicia uvicorn backend.main:app")
			start_btn.disabled = true


func _on_start_pressed() -> void:
	var sid := session_input.text.strip_edges()
	if sid.is_empty():
		sid = "session_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	GameManager.initialize_session(sid, "intermediate")
	get_tree().change_scene_to_file(NEXT_SCENE)


func _on_exit_pressed() -> void:
	# Delegar al BackendLauncher que muestra el diálogo de confirmación
	# y maneja el shutdown del backend + cierre del juego.
	BackendLauncher.request_quit_confirmation()


func _on_retry_pressed() -> void:
	_retries = 0
	_health_ok = false
	_set_ui_locked(true)
	_set_status("checking", "Verificando servidor...")
	_check_backend()


func _on_retry_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_retry_pressed()


func _on_session_input_text_submitted(_new_text: String) -> void:
	if not start_btn.disabled:
		_on_start_pressed()
