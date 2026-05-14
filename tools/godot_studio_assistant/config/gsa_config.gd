@tool
extends Resource
class_name GSAConfig

@export var baseline_godot_major: int = 4
@export var baseline_godot_minor: int = 6
@export var warn_if_engine_minor_differs: bool = true

@export var output_dir_res: String = "res://.gsa"
@export var context_dir_res: String = "res://.gsa/context"

@export var exclude_dir_prefixes: PackedStringArray = PackedStringArray([
	"res://.godot",
	"res://.gsa",
	"res://.import"
	,
	"res://.git"
])

@export var scene_extensions: PackedStringArray = PackedStringArray(["tscn", "scn"])

@export var context_include_extensions: PackedStringArray = PackedStringArray([
	"gd",
	"tscn",
	"tres",
	"cfg",
	"md"
])

@export var context_max_files: int = 200
@export var context_max_bytes_per_file: int = 20000


func to_dict() -> Dictionary:
	return {
		"baseline": {
			"major": baseline_godot_major,
			"minor": baseline_godot_minor,
		},
		"warn_if_engine_minor_differs": warn_if_engine_minor_differs,
		"output_dir_res": output_dir_res,
		"context_dir_res": context_dir_res,
		"exclude_dir_prefixes": Array(exclude_dir_prefixes),
		"scene_extensions": Array(scene_extensions),
		"context_include_extensions": Array(context_include_extensions),
		"context_max_files": context_max_files,
		"context_max_bytes_per_file": context_max_bytes_per_file,
	}
