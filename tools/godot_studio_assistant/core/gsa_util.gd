extends RefCounted


static func ensure_dir_res(dir_res_path: String) -> Error:
	var dir_global = ProjectSettings.globalize_path(dir_res_path)
	return DirAccess.make_dir_recursive_absolute(dir_global)


static func write_file_text(file_res_path: String, text: String) -> Error:
	var parent_res = file_res_path.get_base_dir()
	var err = ensure_dir_res(parent_res)
	if err != OK:
		return err
	var f = FileAccess.open(file_res_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	return OK


static func read_file_text(file_res_path: String) -> String:
	var f = FileAccess.open(file_res_path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


static func read_file_text_max_bytes(file_res_path: String, max_bytes: int) -> Dictionary:
	var f = FileAccess.open(file_res_path, FileAccess.READ)
	if f == null:
		return {
			"ok": false,
			"error": error_string(FileAccess.get_open_error()),
			"text": "",
			"bytes_read": 0,
			"total_bytes": 0,
			"truncated": false,
		}

	var total = int(f.get_length())
	var to_read = total
	if max_bytes > 0:
		to_read = min(total, max_bytes)

	var data: PackedByteArray = f.get_buffer(to_read)
	var text = data.get_string_from_utf8()
	var truncated = to_read < total
	if truncated:
		text += "\n\n[GSA] TRUNCATED: read %d/%d bytes\n" % [to_read, total]

	return {
		"ok": true,
		"error": "",
		"text": text,
		"bytes_read": to_read,
		"total_bytes": total,
		"truncated": truncated,
	}


static func list_files_recursive(root_res_path: String, exts: PackedStringArray, exclude_dir_prefixes: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	_walk(root_res_path, exts, exclude_dir_prefixes, out)
	return out


static func _walk(dir_res_path: String, exts: PackedStringArray, exclude_dir_prefixes: PackedStringArray, out: PackedStringArray) -> void:
	if _is_excluded_dir(dir_res_path, exclude_dir_prefixes):
		return

	var da = DirAccess.open(dir_res_path)
	if da == null:
		return

	da.list_dir_begin()
	while true:
		var name = da.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue

		var child = dir_res_path.path_join(name)
		if da.current_is_dir():
			_walk(child, exts, exclude_dir_prefixes, out)
		else:
			var ext = name.get_extension().to_lower()
			if exts.has(ext):
				out.append(child)
	da.list_dir_end()


static func _is_excluded_dir(dir_res_path: String, exclude_dir_prefixes: PackedStringArray) -> bool:
	for prefix in exclude_dir_prefixes:
		var p = String(prefix)
		if p == "":
			continue
		if dir_res_path == p:
			return true
		if dir_res_path.begins_with(p + "/"):
			return true
	return false
