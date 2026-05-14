extends Control

## Loading screen — hace polling de /health, transiciona a la escena del nivel.

const NEXT_SCENE := "res://scenes/level/el_agave_y_la_luna_main.tscn"
const POLL_INTERVAL_SEC := 1.0
const MAX_WAIT_SEC := 600.0
const RETRY_AFTER_SEC := 2.0
const LOG_TAIL_INTERVAL_SEC := 0.5

@onready var _status: Label = $CenterContainer/VBox/Status
@onready var _spinner: Label = $CenterContainer/VBox/Spinner
@onready var _retry_btn: Button = $CenterContainer/VBox/RetryButton

var _elapsed: float = 0.0
var _spinner_phase: int = 0
var _polling: bool = false
var _stage_text: String = "Iniciando sistema de IA..."
var _last_log_line: String = ""
var _log_tail_accum: float = 0.0


func _ready() -> void:
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

	_log_tail_accum += delta
	if _log_tail_accum >= LOG_TAIL_INTERVAL_SEC:
		_log_tail_accum = 0.0
		_refresh_log_status()

	if _elapsed > MAX_WAIT_SEC:
		_fail("Backend no respondio en %d segundos" % MAX_WAIT_SEC)


func _start_sequence() -> void:
	_stage_text = "Iniciando sistema de IA..."
	_last_log_line = ""
	_polling = true
	_elapsed = 0.0
	_log_tail_accum = 0.0
	_retry_btn.visible = false
	_render_status()
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
		_stage_text = "Listo. Cargando..."
		_render_status()
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file(NEXT_SCENE)
	else:
		await get_tree().create_timer(POLL_INTERVAL_SEC).timeout
		_poll()


func _fail(reason: String) -> void:
	_polling = false
	_spinner.text = "✗"
	_stage_text = reason
	_render_status()
	_retry_btn.visible = true


func _on_retry_pressed() -> void:
	BackendLauncher.launch()
	_start_sequence()


func _on_backend_failed(reason: String) -> void:
	_fail("Backend no inicio: %s" % reason)


# ── Status display ────────────────────────────────────────────────────────

func _refresh_log_status() -> void:
	var line := BackendLauncher.read_log_tail()
	if line.is_empty():
		_render_status()
		return
	if line != _last_log_line:
		_last_log_line = line
	var mapped := _map_log_to_stage(line)
	if not mapped.is_empty():
		_stage_text = mapped
	_render_status()


## Convierte una linea del backend log en un mensaje amistoso en espanol.
## Devuelve "" si la linea no matchea ningun stage conocido (mantiene el anterior).
func _map_log_to_stage(line: String) -> String:
	var l := line.to_lower()
	if l.find("downloading ollama") >= 0 or l.find("ollamasetup") >= 0 or l.find("running ollama installer") >= 0:
		return "Instalando Ollama..."
	if l.find("pulling ollama model") >= 0 or (l.find("pulling") >= 0 and l.find("manifest") >= 0):
		return "Descargando modelo LLM (puede tardar varios minutos)..."
	if l.find("already present") >= 0 and l.find("ollama") >= 0:
		return "Modelo LLM listo."
	if l.find("downloading whisper") >= 0:
		return "Descargando reconocimiento de voz..."
	if l.find("whisper model already present") >= 0:
		return "Modelo de voz listo."
	if l.find("loading faster-whisper") >= 0:
		return "Cargando reconocimiento de voz..."
	if l.find("faster-whisper model loaded") >= 0:
		return "Reconocimiento de voz listo."
	if l.find("warming up ollama") >= 0:
		return "Calentando modelo LLM..."
	if l.find("ollama model warmup complete") >= 0:
		return "Modelo LLM caliente."
	if l.find("ollama connection ok") >= 0:
		return "Ollama conectado."
	if l.find("limonchero backend starting") >= 0:
		return "Backend iniciando..."
	if l.find("uvicorn running") >= 0 or l.find("application startup complete") >= 0:
		return "Servidor activo, conectando..."
	if l.find("ollama did not respond") >= 0 or l.find("ollama not found") >= 0:
		return "Error: Ollama no responde."
	if l.find("error") >= 0 or l.find("traceback") >= 0:
		return "Error en backend (ver backend.log)."
	return ""


func _render_status() -> void:
	var t := "%s\n[%ds transcurridos]" % [_stage_text, int(_elapsed)]
	if not _last_log_line.is_empty():
		var snippet := _last_log_line
		if snippet.length() > 90:
			snippet = snippet.substr(snippet.length() - 90)
		t += "\n%s" % snippet
	_status.text = t
