extends CanvasLayer

signal close_requested
## Emitido cuando el jugador empieza a grabar (mantiene V).
## Backend STT/LLM debe conectarse aqui.
signal recording_started
## Emitido cuando el jugador suelta V. Backend procesa el audio capturado.
signal recording_stopped

@onready var _panel: PanelContainer = $Panel
@onready var _npc_name: Label = $Panel/VBox/NpcName
@onready var _chat_log: RichTextLabel = $Panel/VBox/ChatBg/ChatLog
@onready var _status: Label = $Panel/VBox/StatusBg/Status

var _npc: Node = null
var _is_recording: bool = false


func show_panel(npc: Node) -> void:
	_npc = npc
	_npc_name.text = npc.npc_name if "npc_name" in npc else "NPC"
	_chat_log.text = ""
	_set_idle_status()
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false
	_npc = null
	_is_recording = false


func is_open() -> bool:
	return _panel.visible


## Llamado por el backend cuando el STT termina (texto del jugador).
func add_player_message(text: String) -> void:
	_chat_log.append_text("\n[b][color=lightblue]Tú:[/color][/b] %s" % text)
	set_status("Esperando respuesta...")


## Llamado por el backend cuando llega respuesta del NPC (LLM).
func add_npc_message(text: String) -> void:
	var name_text := _npc_name.text
	_chat_log.append_text("\n[b][color=orange]%s:[/color][/b] %s" % [name_text, text])
	_set_idle_status()


func set_status(text: String) -> void:
	_status.text = text


func _set_idle_status() -> void:
	_status.text = "Mantén [V] para hablar — [Esc] para salir"


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return

	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			close_requested.emit()
			return
		if event.keycode == KEY_V:
			if event.pressed and not _is_recording:
				_is_recording = true
				set_status("● Grabando... (suelta V)")
				recording_started.emit()
			elif not event.pressed and _is_recording:
				_is_recording = false
				set_status("Procesando...")
				recording_stopped.emit()
