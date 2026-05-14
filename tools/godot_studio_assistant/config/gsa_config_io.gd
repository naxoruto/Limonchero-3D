@tool
extends RefCounted

const DEFAULT_CONFIG_PATH := "res://gsa_config.tres"
const DEFAULT_EXPORT_JSON_PATH := "res://gsa_config.export.json"


static func load_config(path: String = DEFAULT_CONFIG_PATH) -> GSAConfig:
	if not FileAccess.file_exists(path):
		return null
	var res = load(path)
	if res is GSAConfig:
		return res
	return null


static func load_or_default(path: String = DEFAULT_CONFIG_PATH) -> GSAConfig:
	var cfg = load_config(path)
	if cfg != null:
		return cfg
	return GSAConfig.new()


static func ensure_config(path: String = DEFAULT_CONFIG_PATH) -> GSAConfig:
	var cfg = load_config(path)
	if cfg != null:
		return cfg

	cfg = GSAConfig.new()
	var err = ResourceSaver.save(cfg, path)
	if err != OK:
		return null
	return cfg


static func export_json(cfg: GSAConfig, json_path: String = DEFAULT_EXPORT_JSON_PATH) -> Error:
	var text = JSON.stringify(cfg.to_dict(), "  ", true) + "\n"
	return GSAUtil.write_file_text(json_path, text)


const GSAConfig := preload("res://addons/godot_studio_assistant/config/gsa_config.gd")
const GSAUtil := preload("res://addons/godot_studio_assistant/core/gsa_util.gd")
