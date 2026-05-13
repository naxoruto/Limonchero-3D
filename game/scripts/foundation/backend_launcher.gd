extends Node
## BackendLauncher — Autoload. Lanza y mata el backend Python (FastAPI).
## Se conecta al cierre del juego para cleanup automatico.

signal backend_started(pid: int)
signal backend_failed(reason: String)

var _backend_pid: int = -1
const _BACKEND_BIN_ENV := "LIMONCHERO_BACKEND_BIN"
const _BACKEND_BIN_NAME := "limonchero-backend"


func _ready() -> void:
	# Cleanup automatico al cerrar la ventana del juego.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()
		get_tree().quit()


## Lanza el backend como proceso separado (binario empaquetado o override).
## Si no hay binario disponible, falla.
func launch() -> bool:
	if _backend_pid > 0:
		# Ya esta corriendo (verificar con OS.is_process_running si hace falta).
		return true

	var command := _resolve_backend_command()
	var exe: String = command["exe"]
	var args: Array = command["args"]

	if exe.is_empty():
		var msg := "Backend no encontrado: no hay binario ni main.py disponible."
		push_error(msg)
		backend_failed.emit(msg)
		return false

	# Si Godot corre dentro de un sandbox Flatpak, lanzamos el backend en el
	# host via flatpak-spawn --host. Si no, ejecutamos directamente.
	if _is_flatpak():
		var host_exe := exe
		exe = "flatpak-spawn"
		args = ["--host", host_exe] + args

	_backend_pid = OS.create_process(exe, args)
	if _backend_pid <= 0:
		var msg := "OS.create_process fallo (exe=%s)" % exe
		push_error(msg)
		backend_failed.emit(msg)
		return false

	print("BackendLauncher: backend lanzado pid=", _backend_pid, " usando ", exe, " ", args)
	backend_started.emit(_backend_pid)
	return true


func _is_flatpak() -> bool:
	return FileAccess.file_exists("/.flatpak-info")


## Mata el proceso backend (idempotente).
func stop() -> void:
	if _backend_pid > 0:
		if _is_flatpak():
			# _backend_pid es el pid de flatpak-spawn dentro del sandbox.
			# Matamos al hijo en el host por nombre + script para asegurar cleanup.
			OS.execute("flatpak-spawn", ["--host", "pkill", "-f", _BACKEND_BIN_NAME])
		OS.kill(_backend_pid)
		print("BackendLauncher: backend pid=", _backend_pid, " terminado")
		_backend_pid = -1


func is_running() -> bool:
	return _backend_pid > 0


func _resolve_backend_command() -> Dictionary:
	var override := OS.get_environment(_BACKEND_BIN_ENV).strip_edges()
	if not override.is_empty() and FileAccess.file_exists(override):
		return {"exe": override, "args": []}

	var bin_name := _BACKEND_BIN_NAME
	if OS.get_name() == "Windows":
		bin_name += ".exe"

	var res_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var candidates: Array = []
	# 1) backend junto a res://
	candidates.append(res_dir.path_join("backend").path_join(bin_name))
	# 2) backend en directorios padres (ej: ./backend al lado de ./game)
	var current := res_dir
	for _i in range(5):
		var parent := current.get_base_dir()
		if parent == current:
			break
		current = parent
		candidates.append(current.path_join("backend").path_join(bin_name))
	# 3) backend junto al ejecutable
	candidates.append(res_dir.path_join(bin_name))

	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return {"exe": candidate, "args": []}

	return {"exe": "", "args": []}
