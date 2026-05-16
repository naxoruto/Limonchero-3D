extends Node
## BackendLauncher — Autoload. Lanza el backend local y lo mata al cerrar.
##
## Layout esperado (release / export):
##   <root>/game/<godot.exe|x86_64>
##   <root>/backend/limonchero-backend[.exe]
##
## En editor (dev): no lanza nada. Asume backend corriendo manualmente.

signal backend_started(pid: int)
signal backend_failed(reason: String)
## Emitida cuando el usuario confirma que quiere salir (diálogo de confirmación).
signal quit_confirmed

const BACKEND_DIR_NAME := "backend"
const LINUX_BIN := "limonchero-backend"
const WINDOWS_BIN := "limonchero-backend.exe"
const LOG_FILE_NAME := "backend.log"
const SKIP_LAUNCH_ENV := "LIMONCHERO_SKIP_BACKEND_LAUNCH"
const BACKEND_SHUTDOWN_URL := "http://127.0.0.1:8000/shutdown"

var _pid: int = -1
var _binary_path: String = ""
var _log_path: String = ""

## Diálogo de confirmación de salida (shared, creado una sola vez).
var _exit_dialog: ConfirmationDialog = null
## Flag para evitar reentrar en la lógica de cierre.
var _quit_pending: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_create_exit_dialog()
	if OS.has_feature("editor"):
		print("[BackendLauncher] Editor mode — backend externo asumido.")
		return
	if OS.get_environment(SKIP_LAUNCH_ENV).strip_edges() != "":
		print("[BackendLauncher] %s set — skip auto-launch." % SKIP_LAUNCH_ENV)
		return
	call_deferred("launch")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# No cerrar directamente — mostrar diálogo de confirmación.
		if _quit_pending:
			return
		request_quit_confirmation()


func request_quit_confirmation() -> void:
	"""Muestra el diálogo de confirmación de salida."""
	if _quit_pending:
		return
	if _exit_dialog == null:
		_create_exit_dialog()
	if not _exit_dialog.visible:
		_exit_dialog.popup_centered()


func _create_exit_dialog() -> void:
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "Salir del juego"
	_exit_dialog.dialog_text = "¿Estás seguro de que quieres salir del juego?\nSe detendrá el servidor del backend automáticamente."
	_exit_dialog.ok_button_text = "Sí, salir"
	_exit_dialog.cancel_button_text = "No, volver"
	_exit_dialog.min_size = Vector2(400, 150)
	_exit_dialog.confirmed.connect(_on_quit_confirmed)
	_exit_dialog.canceled.connect(_on_quit_canceled)
	# Asegurar que aparece encima de todo.
	_exit_dialog.always_on_top = true
	add_child(_exit_dialog)


func _on_quit_confirmed() -> void:
	_quit_pending = true
	quit_confirmed.emit()
	_shutdown_and_quit()


func _on_quit_canceled() -> void:
	# No hacer nada — el jugador decidió quedarse.
	pass


func _shutdown_and_quit() -> void:
	"""Detiene el backend (HTTP + kill process) y cierra el juego."""
	# 1. Intentar shutdown graceful via HTTP.
	_request_backend_shutdown()
	# 2. Kill the process directly (backup).
	stop()
	# 3. Intentar matar por nombre del ejecutable (para el caso de .exe en Windows
	#    o backend corriendo manualmente por consola).
	_kill_backend_by_name()
	# 4. Esperar un frame para que el HTTP request se envíe.
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _request_backend_shutdown() -> void:
	"""Envía POST /shutdown al backend para un cierre graceful."""
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 2.0
	var headers := ["Content-Type: application/json"]
	var err := http.request(BACKEND_SHUTDOWN_URL, headers, HTTPClient.METHOD_POST, "{}")
	if err != OK:
		print("[BackendLauncher] HTTP shutdown request failed (err=%d)" % err)


func _kill_backend_by_name() -> void:
	"""Mata el proceso del backend buscando por nombre del ejecutable.
	Funciona tanto en Windows (taskkill) como en Linux (pkill)."""
	if OS.has_feature("windows"):
		# Windows: taskkill /F /IM limonchero-backend.exe
		var args := ["/F", "/IM", WINDOWS_BIN]
		print("[BackendLauncher] taskkill %s" % " ".join(args))
		OS.create_process("taskkill", args, false)
	else:
		# Linux/macOS: pkill -f limonchero-backend
		var args := ["-f", LINUX_BIN]
		print("[BackendLauncher] pkill %s" % " ".join(args))
		OS.create_process("pkill", args, false)


func launch() -> bool:
	if is_running():
		print("[BackendLauncher] Ya corriendo (pid=%d)." % _pid)
		backend_started.emit(_pid)
		return true

	var exe_path := OS.get_executable_path()
	var exe_dir := exe_path.get_base_dir()
	print("[BackendLauncher] OS.get_executable_path() = %s" % exe_path)
	print("[BackendLauncher] exe_dir = %s" % exe_dir)
	var candidates := _candidate_paths()
	for c in candidates:
		print("[BackendLauncher] Probando: %s (exists=%s)" % [c, FileAccess.file_exists(c)])

	_binary_path = _resolve_binary_path()
	if _binary_path.is_empty():
		var msg := "Binario no encontrado. Paths probados:\n  - %s" % "\n  - ".join(candidates)
		push_warning("[BackendLauncher] " + msg)
		backend_failed.emit(msg)
		return false

	_log_path = OS.get_user_data_dir().path_join(LOG_FILE_NAME)
	var pid := _spawn_backend(_binary_path, _log_path)
	if pid <= 0:
		var msg2 := "OS.create_process fallo para %s" % _binary_path
		push_error("[BackendLauncher] " + msg2)
		backend_failed.emit(msg2)
		return false

	_pid = pid
	print("[BackendLauncher] Backend lanzado (pid=%d). Log: %s" % [_pid, _log_path])
	backend_started.emit(_pid)
	return true


func stop() -> void:
	if _pid <= 0:
		return
	if not OS.is_process_running(_pid):
		_pid = -1
		return
	print("[BackendLauncher] Killing backend pid=%d" % _pid)
	var err := OS.kill(_pid)
	if err != OK:
		push_warning("[BackendLauncher] OS.kill fallo (err=%d) pid=%d" % [err, _pid])
	_pid = -1


func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


func get_log_path() -> String:
	return _log_path


## Devuelve la ultima linea no vacia del log, o "" si no existe.
func read_log_tail() -> String:
	if _log_path.is_empty():
		return ""
	if not FileAccess.file_exists(_log_path):
		return ""
	var f := FileAccess.open(_log_path, FileAccess.READ)
	if f == null:
		return ""
	var content := f.get_as_text()
	f.close()
	var lines := content.strip_edges().split("\n", false)
	if lines.is_empty():
		return ""
	return lines[lines.size() - 1].strip_edges()


# ── Internals ──────────────────────────────────────────────────────────────

func _platform_bin_name() -> String:
	if OS.has_feature("windows"):
		return WINDOWS_BIN
	return LINUX_BIN


func _resolve_binary_path() -> String:
	for path in _candidate_paths():
		if FileAccess.file_exists(path):
			return path
	return ""


func _candidate_paths() -> Array[String]:
	var bin_name := _platform_bin_name()
	var exe_dir := OS.get_executable_path().get_base_dir()
	return [
		# Layout 1: <root>/game/<exe>  +  <root>/backend/<bin>   (paquete release)
		exe_dir.get_base_dir().path_join(BACKEND_DIR_NAME).path_join(bin_name),
		# Layout 2: <root>/<exe>  +  <root>/backend/<bin>
		exe_dir.path_join(BACKEND_DIR_NAME).path_join(bin_name),
		# Layout 3: <exe_dir>/<bin>  (binario al lado)
		exe_dir.path_join(bin_name),
	]


## Spawnea el binario directamente.
## El backend escribe su propio log en la ruta indicada.
func _spawn_backend(binary: String, log_file: String) -> int:
	return OS.create_process(binary, ["--log-file", log_file], false)
