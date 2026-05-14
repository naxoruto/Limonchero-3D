extends Node
## BackendLauncher — Autoload. Lanza el backend local y lo mata al cerrar.
##
## Layout esperado (AppImage / export):
##   <root>/game/<godot.exe|x86_64>
##   <root>/backend/limonchero-backend[.exe]
##
## En editor (dev): no lanza nada. Asume backend corriendo manualmente.

signal backend_started(pid: int)
signal backend_failed(reason: String)

const BACKEND_DIR_NAME := "backend"
const LINUX_BIN := "limonchero-backend"
const WINDOWS_BIN := "limonchero-backend.exe"
const LOG_FILE_NAME := "backend.log"
const SKIP_LAUNCH_ENV := "LIMONCHERO_SKIP_BACKEND_LAUNCH"

var _pid: int = -1
var _binary_path: String = ""
var _log_path: String = ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	if OS.has_feature("editor"):
		print("[BackendLauncher] Editor mode — backend externo asumido.")
		return
	if OS.get_environment(SKIP_LAUNCH_ENV).strip_edges() != "":
		print("[BackendLauncher] %s set — skip auto-launch." % SKIP_LAUNCH_ENV)
		return
	call_deferred("launch")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()
		get_tree().quit()


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

	_log_path = _binary_path.get_base_dir().path_join(LOG_FILE_NAME)
	var pid := _spawn_with_logging(_binary_path, _log_path)
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
		# Layout 1: <root>/game/<exe>  +  <root>/backend/<bin>   (AppImage / squashfs-root)
		exe_dir.get_base_dir().path_join(BACKEND_DIR_NAME).path_join(bin_name),
		# Layout 2: <root>/<exe>  +  <root>/backend/<bin>
		exe_dir.path_join(BACKEND_DIR_NAME).path_join(bin_name),
		# Layout 3: <exe_dir>/<bin>  (binario al lado)
		exe_dir.path_join(bin_name),
	]


## Spawnea el binario redirigiendo stdout/stderr a un archivo log.
## Usa shell wrapper porque OS.create_process no soporta redireccion directa.
func _spawn_with_logging(binary: String, log_file: String) -> int:
	if OS.has_feature("windows"):
		var cmd := "\"%s\" > \"%s\" 2>&1" % [binary, log_file]
		return OS.create_process("cmd.exe", ["/c", cmd], false)
	# Linux / macOS
	var shell_cmd := "exec \"%s\" > \"%s\" 2>&1" % [
		binary.replace("\"", "\\\""),
		log_file.replace("\"", "\\\""),
	]
	return OS.create_process("/bin/sh", ["-c", shell_cmd], false)
