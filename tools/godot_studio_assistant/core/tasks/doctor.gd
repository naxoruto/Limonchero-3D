
extends RefCounted


static func run(config: GSAConfig, config_path: String) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var info: Array = []
	var artifacts: Dictionary = {}

	if not FileAccess.file_exists("res://project.godot"):
		errors.append({
			"code": "not_a_project",
			"message": "Missing res://project.godot. Run from a Godot project root.",
		})

	var vi := Engine.get_version_info()
	var major := int(vi.get("major", 0))
	var minor := int(vi.get("minor", 0))

	if major != 4:
		errors.append({
			"code": "unsupported_engine_major",
			"message": "Unsupported Godot major version: %d (GSA targets Godot 4.x)" % major,
		})
	elif config.warn_if_engine_minor_differs and minor != config.baseline_godot_minor:
		warnings.append({
			"code": "engine_minor_mismatch",
			"message": "Engine minor is %d but baseline is %d. See docs/engine-reference/godot/COMPATIBILITY.md" % [minor, config.baseline_godot_minor],
		})

	if FileAccess.file_exists(config_path):
		info.append({"code": "config_present", "message": "Config found: %s" % config_path})
	else:
		warnings.append({"code": "config_missing", "message": "Config not found: %s (using defaults)" % config_path})

	var err = GSAUtil.ensure_dir_res(config.output_dir_res)
	if err != OK:
		errors.append({
			"code": "output_dir_unwritable",
			"message": "Failed to create output dir %s (%s)" % [config.output_dir_res, error_string(err)],
		})
	else:
		info.append({"code": "output_dir_ok", "message": "Output dir: %s" % config.output_dir_res})

	var context_err = GSAUtil.ensure_dir_res(config.context_dir_res)
	if context_err != OK:
		warnings.append({
			"code": "context_dir_unwritable",
			"message": "Failed to create context dir %s (%s)" % [config.context_dir_res, error_string(context_err)],
		})
	else:
		info.append({"code": "context_dir_ok", "message": "Context dir: %s" % config.context_dir_res})

	_check_config_values(config, errors, warnings, info)
	_check_project_settings(errors, warnings, info)

	var ok = errors.is_empty()
	return {
		"ok": ok,
		"errors": errors,
		"warnings": warnings,
		"info": info,
		"artifacts": artifacts,
	}


static func _check_config_values(config: GSAConfig, errors: Array, warnings: Array, info: Array) -> void:
	# Path sanity.
	if not config.output_dir_res.begins_with("res://"):
		errors.append({"code": "invalid_output_dir", "message": "output_dir_res must start with res://"})
	if not config.context_dir_res.begins_with("res://"):
		errors.append({"code": "invalid_context_dir", "message": "context_dir_res must start with res://"})

	# Baseline sanity.
	if config.baseline_godot_major != 4:
		warnings.append({"code": "baseline_major_unexpected", "message": "baseline_godot_major is %d (GSA targets Godot 4.x)" % config.baseline_godot_major})
	if config.baseline_godot_minor < 0:
		warnings.append({"code": "baseline_minor_invalid", "message": "baseline_godot_minor is %d" % config.baseline_godot_minor})

	# Context bounds.
	if config.context_max_files <= 0:
		warnings.append({"code": "context_max_files_nonpositive", "message": "context_max_files is %d (no sample files will be included)" % config.context_max_files})
	if config.context_max_bytes_per_file <= 0:
		warnings.append({"code": "context_max_bytes_nonpositive", "message": "context_max_bytes_per_file is %d (sample files will be empty)" % config.context_max_bytes_per_file})

	# Exclusions sanity.
	for p in config.exclude_dir_prefixes:
		var s = String(p)
		if s == "":
			warnings.append({"code": "exclude_empty", "message": "exclude_dir_prefixes contains an empty string"})
			continue
		if not s.begins_with("res://"):
			warnings.append({"code": "exclude_not_res", "message": "exclude_dir_prefixes contains non-res path: %s" % s})

	info.append({"code": "config_sanity_ok", "message": "Config sanity checks complete"})


static func _check_project_settings(errors: Array, warnings: Array, info: Array) -> void:
	# Project name.
	var project_name = str(ProjectSettings.get_setting("application/config/name"))
	if project_name.strip_edges() == "":
		warnings.append({"code": "project_name_missing", "message": "application/config/name is empty"})

	# Main scene.
	var main_scene = str(ProjectSettings.get_setting("application/run/main_scene"))
	if main_scene.strip_edges() == "":
		warnings.append({"code": "main_scene_missing", "message": "application/run/main_scene not set"})
	elif not main_scene.begins_with("res://"):
		warnings.append({"code": "main_scene_invalid", "message": "main_scene is not a res:// path: %s" % main_scene})
	elif not FileAccess.file_exists(main_scene):
		warnings.append({"code": "main_scene_not_found", "message": "main_scene does not exist: %s" % main_scene})

	# Autoload scripts exist.
	for p in ProjectSettings.get_property_list():
		var name = str(p.get("name", ""))
		if not name.begins_with("autoload/"):
			continue
		var val = str(ProjectSettings.get_setting(name))
		if val == "":
			continue
		# Value is usually like "res://path/to/file.gd" or "res://path.gd" with flags.
		var script_path = val.split(",")[0].strip_edges()
		if script_path.begins_with("res://") and not FileAccess.file_exists(script_path):
			warnings.append({"code": "autoload_missing", "message": "Autoload path missing: %s (%s)" % [name, script_path]})

	# Input actions: warn if none.
	if InputMap.get_actions().is_empty():
		warnings.append({"code": "no_input_actions", "message": "InputMap has no actions"})

	info.append({"code": "project_settings_checked", "message": "ProjectSettings checks complete"})


const GSAConfig := preload("res://addons/godot_studio_assistant/config/gsa_config.gd")
const GSAUtil := preload("res://addons/godot_studio_assistant/core/gsa_util.gd")
