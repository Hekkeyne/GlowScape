extends Resource
class_name Item

@export var title: String
@export var icon: Texture2D
@export var texture: Texture2D
@export_multiline var description: String
var level = 1

var _original_stats: Dictionary = {}
var _stats_saved: bool = false

func _save_stats() -> void :
	if _stats_saved:
		return
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			var pname = prop.name
			if pname.begins_with("_") or pname in ["level", "resource_path", "resource_name"]:
				continue
			var value = get(pname)
			if typeof(value) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_VECTOR2]:
				_original_stats[pname] = value
	_stats_saved = true

func reset() -> void :
	_save_stats()
	for key in _original_stats:
		set(key, _original_stats[key])
	level = 1
