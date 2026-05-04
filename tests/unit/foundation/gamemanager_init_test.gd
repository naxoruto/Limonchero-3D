extends GutTest

# Tests for Story 001: Session Initialization (GameManager)
# Covers AC-1 through AC-5.

var _gm: GameManager


func before_each() -> void:
	_gm = GameManager.new()
	add_child_autofree(_gm)


# AC-5: Safe default values exist before any initialize_session() call.
func test_defaults_are_safe_before_initialization() -> void:
	assert_eq(_gm.session_id, "", "session_id default must be empty string")
	assert_eq(_gm.english_level, "intermediate", "english_level default must be 'intermediate'")
	assert_eq(_gm.session_start_time, 0.0, "session_start_time default must be 0.0")
	assert_eq(_gm.clues, {}, "clues default must be empty dict")
	assert_eq(_gm.npcs_interrogated, {}, "npcs_interrogated default must be empty dict")
	assert_eq(_gm.accusation_attempts, [], "accusation_attempts default must be empty array")
	assert_eq(_gm.grammar_errors_count, 0, "grammar_errors_count default must be 0")
	assert_eq(_gm.anti_stall_triggers, {"L1": 0, "L2": 0, "L3": 0}, "anti_stall_triggers default must match spec")
	assert_false(_gm.completed, "completed default must be false")
	assert_false(_gm.correct_accusation, "correct_accusation default must be false")


# AC-1: GameManager has the correct shape and is instantiable (autoload
# registration is a project.godot config item; this test verifies the object
# exposes the expected interface so the autoload registration will be valid).
func test_gamemanager_exposes_initialize_session_method() -> void:
	assert_true(_gm.has_method("initialize_session"),
			"GameManager must expose initialize_session()")


# AC-2: initialize_session stores params and resets all tracked state.
func test_initialize_session_stores_params_and_resets_state() -> void:
	_gm.initialize_session("P01", "intermediate")

	assert_eq(_gm.session_id, "P01", "session_id must be set to 'P01'")
	assert_eq(_gm.english_level, "intermediate", "english_level must be 'intermediate'")
	assert_eq(_gm.clues, {}, "clues must be empty after init")
	assert_eq(_gm.npcs_interrogated, {}, "npcs_interrogated must be empty after init")
	assert_eq(_gm.accusation_attempts, [], "accusation_attempts must be empty after init")
	assert_eq(_gm.grammar_errors_count, 0, "grammar_errors_count must be 0 after init")
	assert_eq(_gm.anti_stall_triggers, {"L1": 0, "L2": 0, "L3": 0},
			"anti_stall_triggers must be reset after init")
	assert_false(_gm.completed, "completed must be false after init")
	assert_false(_gm.correct_accusation, "correct_accusation must be false after init")


# AC-3: session_start_time is recorded as a unix timestamp (> 0) on init call.
func test_initialize_session_records_nonzero_unix_timestamp() -> void:
	_gm.initialize_session("P01", "intermediate")

	assert_gt(_gm.session_start_time, 0.0,
			"session_start_time must be a positive unix timestamp after init")


# AC-4: Calling initialize_session twice produces clean state, not accumulated state.
func test_double_initialize_produces_clean_state_not_accumulated() -> void:
	_gm.initialize_session("P01", "intermediate")
	# Manually dirty the state to simulate in-progress session.
	_gm.clues["F1"] = {"state": "good", "timestamp": 42.0}
	_gm.grammar_errors_count = 7
	_gm.completed = true

	_gm.initialize_session("P02", "advanced")

	assert_eq(_gm.session_id, "P02", "session_id must reflect second init call")
	assert_eq(_gm.english_level, "advanced", "english_level must reflect second init call")
	assert_eq(_gm.clues, {}, "clues must be cleared on second init — not accumulated")
	assert_eq(_gm.grammar_errors_count, 0,
			"grammar_errors_count must be reset to 0 on second init")
	assert_false(_gm.completed,
			"completed must be reset to false on second init")
