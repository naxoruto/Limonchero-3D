extends RefCounted


static func run(config: GSAConfig) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var info: Array = []
	var artifacts: Dictionary = {}

	var exts := PackedStringArray()
	for e in config.scene_extensions:
		exts.append(String(e).to_lower())

	var scene_paths = GSAUtil.list_files_recursive("res://", exts, config.exclude_dir_prefixes)
	info.append({"code": "scene_count", "message": "Found %d scene files" % scene_paths.size()})

	var missing_ext_resource_count := 0
	var load_failed_count := 0

	for scene_path in scene_paths:
		var ext = scene_path.get_extension().to_lower()
		if ext == "tscn":
			missing_ext_resource_count += _lint_tscn(scene_path, errors, warnings)
		# Always attempt to load (covers parse errors and some broken refs)
		var res = ResourceLoader.load(scene_path)
		if res == null:
			load_failed_count += 1
			errors.append({
				"code": "scene_load_failed",
				"scene": scene_path,
				"message": "Failed to load scene resource",
			})

	info.append({"code": "scene_lint_summary", "message": "Missing ext_resources: %d, load failures: %d" % [missing_ext_resource_count, load_failed_count]})

	var ok = errors.is_empty()
	return {
		"ok": ok,
		"errors": errors,
		"warnings": warnings,
		"info": info,
		"artifacts": artifacts,
	}


static func _lint_tscn(scene_path: String, errors: Array, warnings: Array) -> int:
	var issue_count := 0
	var text = GSAUtil.read_file_text(scene_path)
	if text == "":
		warnings.append({
			"code": "scene_empty_or_unreadable",
			"scene": scene_path,
			"message": "Could not read .tscn as text",
		})
		return 0

	var lines = text.split("\n", false)
	for i in range(lines.size()):
		var line = String(lines[i]).strip_edges()
		var line_no = i + 1
		if not line.begins_with("[ext_resource"):
			continue

		var r_type = _extract_attr(line, "type")
		var r_path = _extract_attr(line, "path")
		if r_path == "" or not r_path.begins_with("res://"):
			continue

		if r_type == "Script" and not r_path.ends_with(".gd"):
			warnings.append({
				"code": "script_ext_resource_not_gd",
				"scene": scene_path,
				"line": line_no,
				"resource_path": r_path,
				"message": "Script ext_resource does not end with .gd",
			})

		if FileAccess.file_exists(r_path):
			# If this is a script, try loading it too (catches parse errors).
			if r_type == "Script":
				var scr = ResourceLoader.load(r_path)
				if scr == null:
					errors.append({
						"code": "script_load_failed",
						"scene": scene_path,
						"line": line_no,
						"resource_path": r_path,
						"message": "Failed to load script resource",
					})
			continue

		var issue = {
			"code": "missing_ext_resource",
			"scene": scene_path,
			"line": line_no,
			"resource_type": r_type,
			"resource_path": r_path,
			"message": "Missing ext_resource file",
		}

		if r_type == "Script":
			errors.append(issue)
		else:
			warnings.append(issue)
		issue_count += 1

	return issue_count


static func _extract_attr(line: String, key: String) -> String:
	var needle = key + "=\""
	var start = line.find(needle)
	if start == -1:
		return ""
	start += needle.length()
	var end = line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


const GSAConfig := preload("res://addons/godot_studio_assistant/config/gsa_config.gd")
const GSAUtil := preload("res://addons/godot_studio_assistant/core/gsa_util.gd")
