extends CanvasLayer

## Árbol de acusación final. 4 pasos: intro → evidencias → acusado → confirmación.
## Layer 16. Diálogo scripteado (sin LLM). Cancelable hasta antes de confirmar.
##
## API:
##   open() / close()
##   is_open() -> bool
##
## Signals:
##   opened()
##   canceled()
##   accusation_confirmed(accused: String, evidence: Array)

signal opened()
signal canceled()
signal accusation_confirmed(accused: String, evidence: Array)

const MAX_EVIDENCE := 3
const NPC_SUGGESTIONS := ["moni", "gerry", "lola", "barry", "papolicia"]
const SPUD_QUOTE := "Papolicia: \"Alright, detective. Who did it, and what's your evidence?\""

enum Step { INTRO, EVIDENCE, ACCUSED, CONFIRM }

@onready var _title: Label = $Frame/VBox/Title
@onready var _intro: VBoxContainer = $Frame/VBox/StepIntro
@onready var _intro_quote: Label = $Frame/VBox/StepIntro/Quote
@onready var _intro_cancel: Button = $Frame/VBox/StepIntro/Actions/CancelBtn
@onready var _intro_continue: Button = $Frame/VBox/StepIntro/Actions/ContinueBtn

@onready var _evidence: VBoxContainer = $Frame/VBox/StepEvidence
@onready var _evidence_list: VBoxContainer = $Frame/VBox/StepEvidence/EvidenceScroll/EvidenceList
@onready var _evidence_counter: Label = $Frame/VBox/StepEvidence/Counter
@onready var _evidence_back: Button = $Frame/VBox/StepEvidence/Actions/BackBtn
@onready var _evidence_next: Button = $Frame/VBox/StepEvidence/Actions/NextBtn

@onready var _accused: VBoxContainer = $Frame/VBox/StepAccused
@onready var _accused_input: LineEdit = $Frame/VBox/StepAccused/Input
@onready var _accused_suggestions: HBoxContainer = $Frame/VBox/StepAccused/Suggestions
@onready var _accused_back: Button = $Frame/VBox/StepAccused/Actions/BackBtn
@onready var _accused_next: Button = $Frame/VBox/StepAccused/Actions/NextBtn

@onready var _confirm: VBoxContainer = $Frame/VBox/StepConfirm
@onready var _confirm_summary: Label = $Frame/VBox/StepConfirm/Summary
@onready var _confirm_cancel: Button = $Frame/VBox/StepConfirm/Actions/CancelBtn
@onready var _confirm_yes: Button = $Frame/VBox/StepConfirm/Actions/ConfirmBtn

var _is_open: bool = false
var _current_step: int = Step.INTRO
var _selected_evidence: Array = []
var _evidence_checkboxes: Dictionary = {}  # clue_id -> CheckBox


func _ready() -> void:
	layer = 16
	visible = false
	_intro_quote.text = SPUD_QUOTE
	_wire_buttons()
	_build_suggestions()
	GameManager.accessibility_font_size_changed.connect(_apply_font_size)
	_apply_font_size(GameManager.accessibility_font_size)


func _apply_font_size(size: int) -> void:
	_intro_quote.add_theme_font_size_override("font_size", size)
	_confirm_summary.add_theme_font_size_override("font_size", size)
	for cb in _evidence_checkboxes.values():
		(cb as CheckBox).add_theme_font_size_override("font_size", size)


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_selected_evidence.clear()
	_accused_input.text = ""
	_populate_evidence()
	_show_step(Step.INTRO)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_intro_continue.grab_focus()
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false


func _wire_buttons() -> void:
	_intro_cancel.pressed.connect(_cancel)
	_intro_continue.pressed.connect(_to_evidence)
	_evidence_back.pressed.connect(_to_intro)
	_evidence_next.pressed.connect(_to_accused)
	_accused_back.pressed.connect(_to_evidence)
	_accused_next.pressed.connect(_to_confirm)
	_accused_input.text_changed.connect(_on_accused_input_changed)
	_confirm_cancel.pressed.connect(_to_accused)
	_confirm_yes.pressed.connect(_on_confirm_pressed)


func _build_suggestions() -> void:
	for npc_id in NPC_SUGGESTIONS:
		var btn := Button.new()
		btn.text = npc_id.capitalize()
		btn.pressed.connect(_on_suggestion_pressed.bind(npc_id))
		_accused_suggestions.add_child(btn)


func _show_step(step: int) -> void:
	_current_step = step
	_intro.visible = (step == Step.INTRO)
	_evidence.visible = (step == Step.EVIDENCE)
	_accused.visible = (step == Step.ACCUSED)
	_confirm.visible = (step == Step.CONFIRM)
	match step:
		Step.INTRO:
			_title.text = "ACUSACIÓN FINAL"
			_intro_continue.grab_focus()
		Step.EVIDENCE:
			_title.text = "PRUEBAS — paso 1 de 3"
			_refresh_evidence_state()
			var first_cb := _first_enabled_checkbox()
			if first_cb != null:
				first_cb.grab_focus()
			else:
				_evidence_next.grab_focus()
		Step.ACCUSED:
			_title.text = "ACUSADO — paso 2 de 3"
			_accused_next.disabled = _accused_input.text.strip_edges().is_empty()
			_accused_input.grab_focus()
		Step.CONFIRM:
			_title.text = "CONFIRMAR — paso 3 de 3"
			_refresh_summary()
			_confirm_cancel.grab_focus()


func _first_enabled_checkbox() -> CheckBox:
	for cb in _evidence_checkboxes.values():
		if not (cb as CheckBox).disabled:
			return cb
	return null


# ── Step transitions ─────────────────────────────────────────────────────────

func _to_intro() -> void:
	_show_step(Step.INTRO)


func _to_evidence() -> void:
	_show_step(Step.EVIDENCE)


func _to_accused() -> void:
	_show_step(Step.ACCUSED)


func _to_confirm() -> void:
	_show_step(Step.CONFIRM)


# ── Step 2: Evidence ─────────────────────────────────────────────────────────

func _populate_evidence() -> void:
	for child in _evidence_list.get_children():
		child.queue_free()
	_evidence_checkboxes.clear()

	var clues: Dictionary = GameManager.get_all_clues()
	if clues.is_empty():
		var empty := Label.new()
		empty.text = "Sin pistas recopiladas. No puedes acusar."
		empty.modulate = Color(1, 1, 1, 0.6)
		_evidence_list.add_child(empty)
		return

	# Ordenar: BUENA primero, luego el resto.
	var ordered_ids: Array = clues.keys()
	ordered_ids.sort_custom(func(a, b):
		var sa = (clues[a] as Dictionary).get("state", "")
		var sb = (clues[b] as Dictionary).get("state", "")
		if sa == GameManager.STATE_GOOD and sb != GameManager.STATE_GOOD:
			return true
		if sb == GameManager.STATE_GOOD and sa != GameManager.STATE_GOOD:
			return false
		return String(a) < String(b)
	)

	for clue_id in ordered_ids:
		var clue: Dictionary = clues[clue_id]
		var cb := CheckBox.new()
		var state: String = String(clue.get("state", ""))
		var name: String = String(clue.get("name", clue_id))
		var glyph := "✓" if state == GameManager.STATE_GOOD else ("✗" if state == GameManager.STATE_BAD else "○")
		cb.text = "[%s] %s — %s %s" % [clue_id, name, glyph, state]
		cb.disabled = state != GameManager.STATE_GOOD
		if cb.disabled:
			cb.modulate = Color(1, 1, 1, 0.4)
		cb.add_theme_font_size_override("font_size", GameManager.accessibility_font_size)
		cb.toggled.connect(_on_evidence_toggled.bind(String(clue_id)))
		_evidence_list.add_child(cb)
		_evidence_checkboxes[String(clue_id)] = cb


func _on_evidence_toggled(pressed: bool, clue_id: String) -> void:
	if pressed:
		if not _selected_evidence.has(clue_id):
			_selected_evidence.append(clue_id)
	else:
		_selected_evidence.erase(clue_id)
	_refresh_evidence_state()


func _refresh_evidence_state() -> void:
	_evidence_counter.text = "%d / %d seleccionadas" % [_selected_evidence.size(), MAX_EVIDENCE]
	var at_cap := _selected_evidence.size() >= MAX_EVIDENCE
	for clue_id in _evidence_checkboxes:
		var cb: CheckBox = _evidence_checkboxes[clue_id]
		var clue: Dictionary = GameManager.get_clue(clue_id)
		var is_good := String(clue.get("state", "")) == GameManager.STATE_GOOD
		if not is_good:
			cb.disabled = true
			continue
		if cb.button_pressed:
			cb.disabled = false
		else:
			cb.disabled = at_cap
	_evidence_next.disabled = _selected_evidence.is_empty()


# ── Step 3: Accused ──────────────────────────────────────────────────────────

func _on_accused_input_changed(new_text: String) -> void:
	_accused_next.disabled = new_text.strip_edges().is_empty()


func _on_suggestion_pressed(npc_id: String) -> void:
	_accused_input.text = npc_id.capitalize()
	_accused_next.disabled = false


# ── Step 4: Confirm ──────────────────────────────────────────────────────────

func _refresh_summary() -> void:
	var clue_lines := PackedStringArray()
	for clue_id in _selected_evidence:
		var clue: Dictionary = GameManager.get_clue(clue_id)
		clue_lines.append("  • [%s] %s" % [clue_id, String(clue.get("name", clue_id))])
	var summary := "Acusado: %s\n\nPruebas presentadas:\n%s\n\nEsta acción es irreversible." % [
		_accused_input.text.strip_edges(),
		"\n".join(clue_lines)
	]
	_confirm_summary.text = summary


func _on_confirm_pressed() -> void:
	var accused := _accused_input.text.strip_edges()
	var evidence := _selected_evidence.duplicate()
	close()
	accusation_confirmed.emit(accused, evidence)


# ── Cancel ───────────────────────────────────────────────────────────────────

func _cancel() -> void:
	close()
	canceled.emit()
