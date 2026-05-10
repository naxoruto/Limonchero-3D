extends Node
## BackendLauncher — Autoload. Lanza y mata el backend Python (FastAPI).
## Se conecta al cierre del juego para cleanup automatico.

signal backend_started(pid: int)
signal backend_failed(reason: String)

var _backend_pid: int = -1


func _ready() -> void:
	# Cleanup automatico al cerrar la ventana del juego.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()
		get_tree().quit()


## Lanza el backend Python como proceso separado.
## Usa el venv si existe (backend/.venv/bin/python), si no usa python3 del sistema.
func launch() -> bool:
	if _backend_pid > 0:
		# Ya esta corriendo (verificar con OS.is_process_running si hace falta).
		return true

	var paths := _resolve_paths()
	var python_exe: String = paths["python"]
	var main_py: String = paths["main_py"]

	if not FileAccess.file_exists(main_py):
		var msg := "main.py no encontrado en: %s" % main_py
		push_error(msg)
		backend_failed.emit(msg)
		return false

	# Si Godot corre dentro de un sandbox Flatpak, lanzamos el backend en el
	# host via flatpak-spawn --host. Si no, ejecutamos directamente.
	var exe := python_exe
	var args: Array = [main_py]
	if _is_flatpak():
		exe = "flatpak-spawn"
		args = ["--host", python_exe, main_py]

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
			OS.execute("flatpak-spawn", ["--host", "pkill", "-f", "backend/main.py"])
		OS.kill(_backend_pid)
		print("BackendLauncher: backend pid=", _backend_pid, " terminado")
		_backend_pid = -1


func is_running() -> bool:
	return _backend_pid > 0


# ── Resolucion de paths ──────────────────────────────────────────────

func _resolve_paths() -> Dictionary:
	# res:// → /ruta/proyecto/game/  → repo root es /ruta/proyecto/
	var godot_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var repo_root := godot_dir.get_base_dir()
	var backend_dir := repo_root.path_join("backend")
	var main_py := backend_dir.path_join("main.py")

	# Intenta usar el venv local del backend.
	var python_exe := ""
	if OS.get_name() == "Windows":
		var win_venv := backend_dir.path_join(".venv/Scripts/python.exe")
		python_exe = win_venv if FileAccess.file_exists(win_venv) else "python"
	else:
		var unix_venv := backend_dir.path_join(".venv/bin/python")
		python_exe = unix_venv if FileAccess.file_exists(unix_venv) else "python3"

	return {"python": python_exe, "main_py": main_py}
