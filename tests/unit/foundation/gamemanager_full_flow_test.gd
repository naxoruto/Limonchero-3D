extends GutTest

# Integration test for GameManager full lifecycle: Init -> Gameplay -> Export
# Verifies that all telemetry (including new metrics) is captured in the JSON output.

var _gm: GameManager
var _session_id: String = "TEST_SESSION_123"

func before_each() -> void:
	_gm = GameManager.new()
	add_child_autofree(_gm)

func test_full_gameplay_lifecycle_exports_correct_telemetry() -> void:
	# 1. Initialize
	_gm.initialize_session(_session_id, "advanced")
	
	# 2. Simulate Gameplay
	# Interrogate NPCs
	_gm.register_interrogation("moni")
	_gm.register_interrogation("lola")
	
	# Find Clues
	_gm.add_clue("F1", {"name": "Contract", "state": "BUENA"})
	_gm.add_clue("F2", {"name": "Key", "state": "BUENA"})
	_gm.add_clue("F3", {"name": "Lighter", "state": "BUENA"})
	
	# Grammar Errors
	_gm.register_grammar_error()
	_gm.register_grammar_error()
	
	# Set Error Percentage (New Metric)
	_gm.set_error_percentage(33.3)
	
	# Accusation (Correct)
	# Note: register_accusation handles completion and flag setting
	var is_correct = _gm.register_accusation("barry", ["F1", "F2", "F3"])
	assert_true(is_correct, "Accusation should be correct (Barry + F1,F2,F3)")
	assert_true(_gm.completed, "Session should be marked as completed")
	assert_true(_gm.correct_accusation, "Correct accusation flag should be true")
	
	# 3. Export
	_gm.export_session_json()
	
	# 4. Verify File
	var file_path = "user://session_" + _session_id + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	assert_not_null(file, "Exported JSON file should exist in user://")
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(json_text)
	assert_not_null(json, "JSON should be valid and parsable")
	
	# 5. Validate Data Content
	assert_eq(json["session_id"], _session_id)
	assert_eq(json["english_level"], "advanced")
	assert_gt(json["duration"], 0.0, "Duration should be a positive number")
	assert_eq(json["grammar_errors"], 2)
	assert_eq(json["error_percentage"], 33.3, "Error percentage should be captured")
	assert_eq(json["npcs"]["moni"], json["npcs"]["lola"], "NPC interrogation timestamps should be recorded")
	assert_eq(json["clues"]["F1"]["state"], "BUENA")
	assert_true(json["completed"], "Completed flag should be true in JSON")
	assert_true(json["correct_accusation"], "Correct accusation flag should be true in JSON")
