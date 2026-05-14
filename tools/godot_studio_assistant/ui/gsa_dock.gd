@tool
extends Control

const CONFIG_PATH := "res://gsa_config.tres"

@onready var _btn_create_config: Button = $Margin/Root/Buttons/CreateConfig
@onready var _btn_export_config: Button = $Margin/Root/Buttons/ExportConfig
@onready var _btn_doctor: Button = $Margin/Root/Buttons/RunDoctor
@onready var _btn_scene_lint: Button = $Margin/Root/Buttons/RunSceneLint
@onready var _btn_context_pack: Button = $Margin/Root/Buttons/RunContextPack
@onready var _output: TextEdit = $Margin/Root/Output


func _ready() -> void:
	_btn_create_config.pressed.connect(_on_create_config)
	_btn_export_config.pressed.connect(_on_export_config)
	_btn_doctor.pressed.connect(_on_doctor)
	_btn_scene_lint.pressed.connect(_on_scene_lint)
	_btn_context_pack.pressed.connect(_on_context_pack)

	_log_line("GSA dock ready.")
	_log_line("Not affiliated with the Godot Engine project.")


func _on_create_config() -> void:
	var cfg = GSAConfigIO.ensure_config(CONFIG_PATH)
	if cfg == null:
		_log_line("ERROR: Failed to create config at %s" % CONFIG_PATH)
		return
	_log_line("Config OK: %s" % CONFIG_PATH)


func _on_export_config() -> void:
	var cfg = GSAConfigIO.load_or_default(CONFIG_PATH)
	var err = GSAConfigIO.export_json(cfg)
	if err != OK:
		_log_line("ERROR: Failed to export config JSON (%s)" % error_string(err))
		return
	_log_line("Exported: %s" % GSAConfigIO.DEFAULT_EXPORT_JSON_PATH)


func _on_doctor() -> void:
	_run_task("doctor")


func _on_scene_lint() -> void:
	_run_task("scene-lint")


func _on_context_pack() -> void:
	_run_task("context-pack")


func _run_task(command: String) -> void:
	var cfg = GSAConfigIO.load_or_default(CONFIG_PATH)
	var report = GSARunner.run(command, cfg, CONFIG_PATH)
	_output.text = JSON.stringify(report, "  ", true) + "\n"


func _log_line(line: String) -> void:
	_output.text += line + "\n"


const GSAConfigIO := preload("res://addons/godot_studio_assistant/config/gsa_config_io.gd")
const GSARunner := preload("res://addons/godot_studio_assistant/core/gsa_runner.gd")
