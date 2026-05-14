extends Node

# ── Signals (public API contract — emitted in future stories) ─────────────────
signal clue_added(clue_id: String)
signal clue_state_changed(clue_id: String, state: String)
signal gate_opened()
signal session_initialized(session_id: String)

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
