extends RefCounted

const GSA_VERSION := "0.1.0"


static func run(command: String, config: GSAConfig, config_path: String = "res://gsa_config.tres") -> Dictionary:
	var started_ms = Time.get_ticks_msec()
	var vi := Engine.get_version_info()
	var engine_str := "%d.%d.%d" % [int(vi.get("major", 0)), int(vi.get("minor", 0)), int(vi.get("patch", 0))]

	var result := _run_task(command, config, config_path)
	var timing_ms = Time.get_ticks_msec() - started_ms

	var report := {
		"gsa_version": GSA_VERSION,
		"command": command,
		"ok": bool(result.get("ok", false)),
		"engine": {
			"version": vi,
			"string": engine_str,
		},
		"errors": result.get("errors", []),
		"warnings": result.get("warnings", []),
		"info": result.get("info", []),
		"artifacts": result.get("artifacts", {}),
		"timing_ms": timing_ms,
	}

	# Best-effort: write the report under the configured output directory.
	var report_path = config.output_dir_res.path_join("reports").path_join("%s.json" % command)
	var artifacts: Dictionary = report.get("artifacts", {})
	artifacts["report_json"] = report_path
	report["artifacts"] = artifacts

	var err = GSAUtil.write_file_text(report_path, JSON.stringify(report, "  ", true) + "\n")
	if err != OK:
		report["artifacts"].erase("report_json")
		var w: Array = report.get("warnings", [])
		w.append({
			"code": "report_write_failed",
			"message": "Failed to write report to %s (%s)" % [report_path, error_string(err)],
		})
		report["warnings"] = w

	return report


static func _run_task(command: String, config: GSAConfig, config_path: String) -> Dictionary:
	match command:
		"doctor":
			return GSADoctor.run(config, config_path)
		"scene-lint":
			return GSASceneLint.run(config)
		"context-pack":
			return GSAContextPack.run(config)
		_:
			return {
				"ok": false,
				"errors": [{"code": "unknown_command", "message": "Unknown command: %s" % command}],
				"warnings": [],
				"info": [],
				"artifacts": {},
			}


const GSAConfig := preload("res://addons/godot_studio_assistant/config/gsa_config.gd")
const GSADoctor := preload("res://addons/godot_studio_assistant/core/tasks/doctor.gd")
const GSASceneLint := preload("res://addons/godot_studio_assistant/core/tasks/scene_lint.gd")
const GSAContextPack := preload("res://addons/godot_studio_assistant/core/tasks/context_pack.gd")
const GSAUtil := preload("res://addons/godot_studio_assistant/core/gsa_util.gd")
