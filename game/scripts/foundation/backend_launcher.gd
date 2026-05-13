extends Node
## BackendLauncher — Autoload. Backend externo (no lanza procesos).
## Se conecta al cierre del juego para cleanup automatico.

signal backend_started(pid: int)
signal backend_failed(reason: String)


func _ready() -> void:
	# Cleanup automatico al cerrar la ventana del juego.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()
		get_tree().quit()


## Backend externo: no hay proceso local que lanzar.
func launch() -> bool:
	return true


## Backend externo: no hay proceso local que cerrar.
func stop() -> void:
	pass


func is_running() -> bool:
	return false
