extends CanvasLayer

signal interaction_prompt_clicked()

@onready var crosshair: Label = $Crosshair
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var subtitle_panel: Control = $SubtitlePanel
@onready var ptt_indicator: Control = $PTTIndicator
@onready var inventory_notification: Label = $InventoryNotification
@onready var anti_stall_hint: Label = $AntiStallHint

var _npc_colors := {
	"gajito": Color("#8BC34A"),
	"spud": Color("#6B4423"),
	"moni": Color("#8B2332"),
	"gerry": Color("#4A6B30"),
	"lola": Color("#C4703A"),
	"barry": Color("#D4C840")
}

const _PTT_WAVE_FRAMES := ["▁▂▃", "▂▃▁", "▃▁▂"]
const _PTT_AMBER := Color("#D4A030")
const _PTT_IDLE := Color("#4A4035")

var _ptt_pulse_tween: Tween = null
var _ptt_fade_tween: Tween = null
var _ptt_wave_timer: Timer = null
var _ptt_wave_index: int = 0


func _ready() -> void:
	layer = 10
	_setup_subtitle_panel()
	_ptt_wave_timer = Timer.new()
	_ptt_wave_timer.wait_time = 0.15
	_ptt_wave_timer.one_shot = false
	_ptt_wave_timer.timeout.connect(_on_ptt_wave_tick)
	add_child(_ptt_wave_timer)


func _setup_subtitle_panel() -> void:
	subtitle_panel.visible = false


# ── Interaction Prompt ────────────────────────────────────────────

func set_interaction_prompt(text: String, visible: bool) -> void:
	interaction_prompt.text = text
	interaction_prompt.visible = visible


# ── Subtitles ─────────────────────────────────────────────────────

func show_npc_subtitle(npc_id: String, text: String) -> void:
	var color = _npc_colors.get(npc_id.to_lower(), Color.WHITE)
	var name_label: Label = subtitle_panel.get_node("NPCName")
	var text_label: Label = subtitle_panel.get_node("NPCText")
	name_label.text = "[%s]" % npc_id.capitalize()
	name_label.modulate = color
	_start_typewriter(text_label, text, 0.03)
	subtitle_panel.visible = true


func show_player_subtitle(text: String) -> void:
	var label: Label = subtitle_panel.get_node("PlayerText")
	label.text = "[Tú] %s" % text
	label.modulate = Color("#87CEEB")
	subtitle_panel.visible = true


func clear_subtitles() -> void:
	subtitle_panel.visible = false


func _start_typewriter(label: Label, full_text: String, interval: float) -> void:
	label.text = ""
	var chars := full_text.length()
	for i in chars:
		label.text = full_text.left(i + 1)
		await get_tree().create_timer(interval).timeout


# ── PTT Indicator ─────────────────────────────────────────────────

func set_ptt_state(state: String) -> void:
	var icon: Label = ptt_indicator.get_node("Icon")
	var status: Label = ptt_indicator.get_node("StatusLabel")

	_stop_ptt_pulse()
	_stop_ptt_wave(icon)
	_stop_ptt_fade()

	match state:
		"idle":
			_fade_ptt(ptt_indicator, 0.0, 0.15, true)
			icon.modulate = _PTT_IDLE
			status.modulate = _PTT_IDLE
			status.text = ""
		"recording":
			icon.text = _PTT_WAVE_FRAMES[0]
			icon.modulate = _PTT_AMBER
			status.modulate = _PTT_AMBER
			status.text = "Grabando..."
			ptt_indicator.visible = true
			_ptt_fade_tween = create_tween()
			_ptt_fade_tween.tween_property(ptt_indicator, "modulate:a", 1.0, 0.15)
			_ptt_fade_tween.tween_callback(_start_ptt_pulse.bind(ptt_indicator))
			_start_ptt_wave()
		"processing":
			icon.text = _PTT_WAVE_FRAMES[0]
			icon.modulate = _PTT_AMBER
			status.modulate = _PTT_AMBER
			status.text = "Gajito pensando..."
			ptt_indicator.visible = true
			_fade_ptt(ptt_indicator, 1.0, 0.15, false)


func _fade_ptt(node: CanvasItem, target_alpha: float, duration: float, hide_on_end: bool) -> void:
	_ptt_fade_tween = create_tween()
	_ptt_fade_tween.tween_property(node, "modulate:a", target_alpha, duration)
	if hide_on_end:
		_ptt_fade_tween.tween_callback(func(): node.visible = false)


func _stop_ptt_fade() -> void:
	if _ptt_fade_tween and _ptt_fade_tween.is_valid():
		_ptt_fade_tween.kill()
	_ptt_fade_tween = null


func _start_ptt_pulse(node: CanvasItem) -> void:
	_ptt_pulse_tween = create_tween().set_loops()
	_ptt_pulse_tween.tween_property(node, "modulate:a", 0.6, 0.25)
	_ptt_pulse_tween.tween_property(node, "modulate:a", 1.0, 0.25)


func _stop_ptt_pulse() -> void:
	if _ptt_pulse_tween and _ptt_pulse_tween.is_valid():
		_ptt_pulse_tween.kill()
	_ptt_pulse_tween = null


func _start_ptt_wave() -> void:
	_ptt_wave_index = 0
	_ptt_wave_timer.start()


func _stop_ptt_wave(icon: Label) -> void:
	_ptt_wave_timer.stop()
	icon.text = _PTT_WAVE_FRAMES[0]


func _on_ptt_wave_tick() -> void:
	_ptt_wave_index = (_ptt_wave_index + 1) % _PTT_WAVE_FRAMES.size()
	var icon: Label = ptt_indicator.get_node("Icon")
	icon.text = _PTT_WAVE_FRAMES[_ptt_wave_index]


# ── Inventory Notification ────────────────────────────────────────

func show_inventory_notification(clue_name: String) -> void:
	inventory_notification.text = "[%s] anadida al inventario" % clue_name
	inventory_notification.visible = true
	await get_tree().create_timer(1.5).timeout
	inventory_notification.visible = false


# ── Anti-Stall Hint ───────────────────────────────────────────────

var _hints := {
	1: "Quizas deberias revisar el guardarropa...",
	2: "El piso de arriba podria tener respuestas...",
	3: "Barry Peel. Su reservado. El acuerdo."
}


func show_anti_stall_hint(level: int) -> void:
	if level < 1 or level > 3:
		return
	anti_stall_hint.text = _hints[level]
	anti_stall_hint.visible = true
	await get_tree().create_timer(4.0).timeout
	anti_stall_hint.visible = false


# ── Global visibility toggle ──────────────────────────────────────

func set_hud_visible(visible: bool) -> void:
	subtitle_panel.visible = visible
	ptt_indicator.visible = visible
	interaction_prompt.visible = visible
	inventory_notification.visible = visible
