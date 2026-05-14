extends Node

# ── Signals (public API contract — emitted in future stories) ─────────────────
signal clue_added(clue_id: String)
signal clue_state_changed(clue_id: String, state: String)
signal gate_opened()
signal session_initialized(session_id: String)
signal case_failed(reason: String)   # "wrong_accusation" | "insufficient_evidence"
signal case_resolved()

# ── Clue states ───────────────────────────────────────────────────────────────
const STATE_GOOD := "BUENA"
const STATE_BAD := "MALA"
const STATE_UNREVIEWED := "SIN_REVISAR"
const VALID_STATES := [STATE_GOOD, STATE_BAD, STATE_UNREVIEWED]

# ── Confession gate ──────────────────────────────────────────────────────────
const CONFESSION_CLUES := ["F1", "F2", "F3"]
const CULPRIT_ID := "barry"
const ACCUSATION_REASON_WRONG := "wrong_accusation"
const ACCUSATION_REASON_INSUFFICIENT := "insufficient_evidence"

# ── Session identity ──────────────────────────────────────────────────────────
var session_id: String = ""
var english_level: String = "intermediate"
var session_start_time: float = 0.0

# ── Evidence state ────────────────────────────────────────────────────────────
# Do not write directly — access only through public methods (Stories 002–005).
var clues: Dictionary = {}

# ── Telemetry ─────────────────────────────────────────────────────────────────
var npcs_interrogated: Dictionary = {}
var accusation_attempts: Array = []
var grammar_errors_count: int = 0
var anti_stall_triggers: Dictionary = {"L1": 0, "L2": 0, "L3": 0}

# ── Resolution flags ──────────────────────────────────────────────────────────
var completed: bool = false
var correct_accusation: bool = false

# ── Private bookkeeping ───────────────────────────────────────────────────────
var _session_exported: bool = false
var _timestamp_start: String = ""


func initialize_session(p_session_id: String, p_english_level: String) -> void:
	session_id = p_session_id
	english_level = p_english_level
	session_start_time = Time.get_unix_time_from_system()
	_timestamp_start = Time.get_datetime_string_from_system()
	clues = {}
	npcs_interrogated = {}
	accusation_attempts = []
	grammar_errors_count = 0
	anti_stall_triggers = {"L1": 0, "L2": 0, "L3": 0}
	completed = false
	correct_accusation = false
	_session_exported = false
	session_initialized.emit(session_id)


# ── Clue API ──────────────────────────────────────────────────────────────────

## Agrega una pista nueva al inventario. Devuelve false si ya existía.
## data debe incluir al menos: name, type, state. Otros campos: implica_a, description, icon_path.
func add_clue(clue_id: String, data: Dictionary) -> bool:
	if clue_id.is_empty():
		push_warning("GameManager.add_clue: clue_id vacio")
		return false
	if clues.has(clue_id):
		return false
	var entry := data.duplicate(true)
	entry["id"] = clue_id
	if not entry.has("state") or not VALID_STATES.has(entry["state"]):
		entry["state"] = STATE_UNREVIEWED
	if not entry.has("type"):
		entry["type"] = "physical"
	if not entry.has("name"):
		entry["name"] = clue_id
	clues[clue_id] = entry
	clue_added.emit(clue_id)
	return true


## Cambia el estado de una pista existente. No-op si no existe o estado inválido.
func set_clue_state(clue_id: String, state: String) -> void:
	if not clues.has(clue_id):
		push_warning("GameManager.set_clue_state: clue '%s' no existe" % clue_id)
		return
	if not VALID_STATES.has(state):
		push_warning("GameManager.set_clue_state: estado '%s' invalido" % state)
		return
	if clues[clue_id]["state"] == state:
		return
	clues[clue_id]["state"] = state
	clue_state_changed.emit(clue_id, state)


func get_clue(clue_id: String) -> Dictionary:
	if not clues.has(clue_id):
		return {}
	return (clues[clue_id] as Dictionary).duplicate(true)


func get_all_clues() -> Dictionary:
	return clues.duplicate(true)


func has_clue(clue_id: String) -> bool:
	return clues.has(clue_id)


# ── Confession Gate / Accusation ─────────────────────────────────────────────

## Devuelve true si las 3 pistas requeridas (F1+F2+F3) están en estado BUENA.
func is_confession_gate_open() -> bool:
	for clue_id in CONFESSION_CLUES:
		var clue: Dictionary = clues.get(clue_id, {})
		if clue.get("state", "") != STATE_GOOD:
			return false
	return true


## Registra el intento de acusación en telemetría. Devuelve true si la acusación
## es correcta (Barry + puerta abierta). Emite case_resolved o case_failed.
## Punto de no retorno — la lógica del caller decide la pantalla final.
func register_accusation(accused_id: String, presented_evidence: Array, _is_correct_unused: bool = false) -> bool:
	var normalized := accused_id.strip_edges().to_lower()
	var gate_open := is_confession_gate_open()
	var is_correct := (normalized == CULPRIT_ID) and gate_open

	accusation_attempts.append({
		"accused": normalized,
		"evidence": presented_evidence.duplicate(),
		"is_correct": is_correct,
		"timestamp": Time.get_unix_time_from_system(),
	})

	completed = true
	correct_accusation = is_correct

	if is_correct:
		gate_opened.emit()
		case_resolved.emit()
		return true

	if normalized != CULPRIT_ID:
		case_failed.emit(ACCUSATION_REASON_WRONG)
	else:
		case_failed.emit(ACCUSATION_REASON_INSUFFICIENT)
	return false
