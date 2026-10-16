extends Node2D

var _dummies: Dictionary = {}

func _ready() -> void:
	Net.projectile_snapshot_received.connect(_on_snapshot)

func _on_snapshot(data: Array) -> void:
	if Net.is_host:
		return
	var seen: Dictionary = {}
	for entry in data:
		var id = int(entry.get("id", 0))
		if id <= 0:
			continue
		seen[id] = true
		if _dummies.has(id) and is_instance_valid(_dummies[id]):
			_dummies[id].update_from_snapshot(entry)
		else:
			_spawn_dummy(id, entry)
	var to_remove: Array = []
	for id in _dummies:
		if not seen.has(id):
			to_remove.append(id)
	for id in to_remove:
		if is_instance_valid(_dummies[id]):
			_dummies[id].queue_free()
		_dummies.erase(id)

func _spawn_dummy(id: int, entry: Dictionary) -> void:
	var dummy = preload("res://scene/projectile_dummy.tscn").instantiate()
	get_tree().current_scene.add_child(dummy)
	if entry.has("pos"):
		dummy.global_position = entry.pos
	dummy.update_from_snapshot(entry)
	_dummies[id] = dummy
