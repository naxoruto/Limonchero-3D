extends Control

## Loading screen — lanza el backend, hace polling de /health, transiciona a la escena del nivel.

const NEXT_SCENE := "res://scenes/level/el_agave_y_la_luna_main.tscn"
const EXTERNAL_BACKEND_ENV := "LIMONCHERO_EXTERNAL_BACKEND"
const BACKEND_URL_ENV := "LIMONCHERO_BACKEND_URL"
const POLL_INTERVAL_SEC := 1.0
const MAX_WAIT_SEC := 600.0
const RETRY_AFTER_SEC := 2.0

@onready var _status: Label = $CenterContainer/VBox/Status
@onready var _spinner: Label = $CenterContainer/VBox/Spinner
@onready var _retry_btn: Button = $CenterContainer/VBox/RetryButton

var _elapsed: float = 0.0
var _spinner_phase: int = 0
var _polling: bool = false
var _use_external_backend: bool = false


func _ready() -> void:
	_use_external_backend = _should_use_external_backend()
	_retry_btn.visible = false
	_retry_btn.pressed.connect(_on_retry_pressed)
	LLMClient.health_check_done.connect(_on_health_check_done)
	BackendLauncher.backend_failed.connect(_on_backend_failed)
	_start_sequence()


func _process(delta: float) -> void:
	if not _polling:
		return
	_elapsed += delta
	# Spinner animado simple.
	_spinner_phase = int(_elapsed * 4) % 4
	_spinner.text = ["⣷", "⣯", "⣟", "⡿"][_spinner_phase]
	if _elapsed > MAX_WAIT_SEC:
		_fail("Backend no respondio en %d segundos" % MAX_WAIT_SEC)


func _start_sequence() -> void:
	_set_status("Iniciando sistema de IA...")
	_polling = true
	_elapsed = 0.0
	_retry_btn.visible = false
	if not _use_external_backend:
		if not BackendLauncher.launch():
			return
	else:
		print("Loading: usando backend externo; se omite auto-launch")
	# Espera 2s antes del primer health check (uvicorn tarda en bootear).
	await get_tree().create_timer(RETRY_AFTER_SEC).timeout
	_poll()


func _poll() -> void:
	if not _polling:
		return
	LLMClient.check_health()


func _on_health_check_done(ok: bool) -> void:
	if not _polling:
		return
	if ok:
		_polling = false
		_set_status("Listo. Cargando...")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file(NEXT_SCENE)
	else:
		await get_tree().create_timer(POLL_INTERVAL_SEC).timeout
		_poll()


func _on_backend_failed(reason: String) -> void:
	_fail("Error al lanzar backend: %s" % reason)


func _fail(reason: String) -> void:
	_polling = false
	_spinner.text = "✗"
	_set_status(reason)
	_retry_btn.visible = true


func _on_retry_pressed() -> void:
	_start_sequence()


func _set_status(text: String) -> void:
	_status.text = text


func _should_use_external_backend() -> bool:
	if Engine.is_editor_hint():
		return true
	var url_override := OS.get_environment(BACKEND_URL_ENV).strip_edges()
	if not url_override.is_empty():
		return true
	var override := OS.get_environment(EXTERNAL_BACKEND_ENV).strip_edges().to_lower()
	if override.is_empty():
		return false
	return override in ["1", "true", "yes"]
