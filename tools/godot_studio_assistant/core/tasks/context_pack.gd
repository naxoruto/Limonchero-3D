extends RefCounted


static func run(config: GSAConfig) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var info: Array = []
	var artifacts: Dictionary = {}

	var err = GSAUtil.ensure_dir_res(config.context_dir_res)
	if err != OK:
		errors.append({
			"code": "context_dir_unwritable",
			"message": "Failed to create context dir %s (%s)" % [config.context_dir_res, error_string(err)],
		})
		return {
			"ok": false,
			"errors": errors,
			"warnings": warnings,
			"info": info,
			"artifacts": artifacts,
		}

	var inv = _build_inventory(config)
	var inventory_path = config.context_dir_res.path_join("inventory.json")
	var summary_path = config.context_dir_res.path_join("summary.md")
	var project_copy_path = config.context_dir_res.path_join("project.godot.txt")

	err = GSAUtil.write_file_text(inventory_path, JSON.stringify(inv, "  ", true) + "\n")
	if err != OK:
		errors.append({"code": "write_failed", "path": inventory_path, "message": error_string(err)})

	err = GSAUtil.write_file_text(summary_path, _build_summary_md(inv))
	if err != OK:
		errors.append({"code": "write_failed", "path": summary_path, "message": error_string(err)})

	if FileAccess.file_exists("res://project.godot"):
		var project_text = GSAUtil.read_file_text_max_bytes("res://project.godot", config.context_max_bytes_per_file).get("text", "")
		err = GSAUtil.write_file_text(project_copy_path, project_text)
		if err != OK:
			warnings.append({"code": "project_copy_failed", "path": project_copy_path, "message": error_string(err)})

	artifacts["inventory_json"] = inventory_path
	artifacts["summary_md"] = summary_path
	if FileAccess.file_exists("res://project.godot"):
		artifacts["project_godot_copy"] = project_copy_path

	info.append({"code": "context_pack_written", "message": "Wrote context pack to %s" % config.context_dir_res})

	var ok = errors.is_empty()
	return {
		"ok": ok,
		"errors": errors,
		"warnings": warnings,
		"info": info,
		"artifacts": artifacts,
	}


static func _build_inventory(config: GSAConfig) -> Dictionary:
	var vi := Engine.get_version_info()

	var project_name = str(ProjectSettings.get_setting("application/config/name"))
	var project_version = str(ProjectSettings.get_setting("application/config/version"))

	var autoloads: Array = []
	for p in ProjectSettings.get_property_list():
		var name = str(p.get("name", ""))
		if not name.begins_with("autoload/"):
			continue
		var key = name.substr("autoload/".length())
		autoloads.append({
			"name": key,
			"value": str(ProjectSettings.get_setting(name)),
		})

	autoloads.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))

	var actions: Array = []
	for a in InputMap.get_actions():
		actions.append(str(a))
	actions.sort()

	var script_paths = GSAUtil.list_files_recursive("res://", PackedStringArray(["gd"]), config.exclude_dir_prefixes)
	var scene_paths = GSAUtil.list_files_recursive("res://", PackedStringArray(["tscn", "scn"]), config.exclude_dir_prefixes)

	# Add a small file sample for LLM context (bounded).
	var sample_files: Array = []
	for p in script_paths:
		sample_files.append(String(p))
	for p in scene_paths:
		sample_files.append(String(p))
	sample_files.sort()

	var sample: Array = []
	var max_files = max(0, config.context_max_files)
	for p in sample_files:
		if max_files > 0 and sample.size() >= max_files:
			break
		var ext = String(p).get_extension().to_lower()
		if not config.context_include_extensions.has(ext):
			continue
		var r = GSAUtil.read_file_text_max_bytes(String(p), config.context_max_bytes_per_file)
		if not bool(r.get("ok", false)):
			continue
		sample.append({
			"path": String(p),
			"bytes_read": int(r.get("bytes_read", 0)),
			"total_bytes": int(r.get("total_bytes", 0)),
			"truncated": bool(r.get("truncated", false)),
			"text": String(r.get("text", "")),
		})

	return {
		"generated_at": Time.get_datetime_string_from_system(),
		"engine": {
			"version": vi,
		},
		"project": {
			"name": project_name,
			"version": project_version,
			"autoloads": autoloads,
			"input_actions": actions,
		},
		"inventory": {
			"scripts": {
				"count": script_paths.size(),
				"paths": Array(script_paths),
			},
			"scenes": {
				"count": scene_paths.size(),
				"paths": Array(scene_paths),
			},
		},
		"sample_files": sample,
	}


static func _build_summary_md(inv: Dictionary) -> String:
	var project = inv.get("project", {})
	var engine = inv.get("engine", {})
	var inventory = inv.get("inventory", {})

	var lines: Array[String] = []
	lines.append("# GSA Context Pack Summary\n")
	lines.append("Generated: %s\n" % str(inv.get("generated_at", "")))
	lines.append("Project: %s (%s)\n" % [str(project.get("name", "")), str(project.get("version", ""))])
	lines.append("Engine: %s\n" % JSON.stringify(engine.get("version", {}), "", true))

	lines.append("\n## Autoloads\n")
	var autoloads: Array = project.get("autoloads", [])
	if autoloads.is_empty():
		lines.append("(none)\n")
	else:
		for a in autoloads:
			lines.append("- %s: %s\n" % [str(a.get("name", "")), str(a.get("value", ""))])

	lines.append("\n## Input Actions\n")
	var actions: Array = project.get("input_actions", [])
	if actions.is_empty():
		lines.append("(none)\n")
	else:
		for action in actions:
			lines.append("- %s\n" % str(action))

	lines.append("\n## Inventory\n")
	var scripts = inventory.get("scripts", {})
	var scenes = inventory.get("scenes", {})
	lines.append("Scripts: %s\n" % str(scripts.get("count", 0)))
	lines.append("Scenes: %s\n" % str(scenes.get("count", 0)))

	return "".join(lines)


const GSAConfig := preload("res://addons/godot_studio_assistant/config/gsa_config.gd")
const GSAUtil := preload("res://addons/godot_studio_assistant/core/gsa_util.gd")
