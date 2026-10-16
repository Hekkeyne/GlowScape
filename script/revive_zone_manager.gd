extends Node2D

@export var zone_scene: PackedScene

var _zones: Dictionary = {}

func _ready() -> void:
	Net.revive_zone_spawned.connect(_on_zone_spawned)
	Net.revive_zone_removed.connect(_on_zone_removed)

func _on_zone_spawned(pos: Vector2, dead_player_id: int) -> void:
	if _zones.has(dead_player_id):
		if is_instance_valid(_zones[dead_player_id]):
			_zones[dead_player_id].queue_free()
		_zones.erase(dead_player_id)
	var zone = zone_scene.instantiate()
	zone.global_position = pos
	zone.dead_player_id = dead_player_id
	get_tree().current_scene.add_child.call_deferred(zone)
	_zones[dead_player_id] = zone

func _on_zone_removed(dead_player_id: int) -> void:
	if not _zones.has(dead_player_id):
		return
	if is_instance_valid(_zones[dead_player_id]):
		_zones[dead_player_id].queue_free()
	_zones.erase(dead_player_id)
