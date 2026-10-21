extends Node2D

@export var marker_scene: PackedScene
@export var update_interval: float = 0.1

var _markers: Dictionary = {}
var _timer: float = 0.0

func _process(delta: float) -> void :
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_update_all_markers()

func _update_all_markers() -> void :
	var seen: Dictionary = {}
	var targets: Array = []
	for node in get_tree().get_nodes_in_group("MegaGem"):
		if is_instance_valid(node):
			targets.append({"node": node, "type": "mega_gem", "elite": false})
	for node in get_tree().get_nodes_in_group("PickupItem"):
		if is_instance_valid(node):
			targets.append({"node": node, "type": "pickup", "elite": false})
	for node in get_tree().get_nodes_in_group("Destructible"):
		if is_instance_valid(node):
			targets.append({"node": node, "type": "destructible", "elite": false})
	for node in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(node) and "is_elite" in node and node.is_elite:
			targets.append({"node": node, "type": "elite", "elite": true})
	for entry in targets:
		var node = entry.node
		var id = node.get_instance_id()
		seen[id] = true
		if _markers.has(id):
			if is_instance_valid(_markers[id]):
				_markers[id].target = node
				_markers[id].update_marker()
			else:
				_markers.erase(id)
				_spawn_marker(id, entry)
		else:
			_spawn_marker(id, entry)
	var to_remove: Array = []
	for id in _markers:
		if not seen.has(id):
			to_remove.append(id)
	for id in to_remove:
		if is_instance_valid(_markers[id]):
			_markers[id].queue_free()
		_markers.erase(id)

func _spawn_marker(id: int, entry: Dictionary) -> void :
	if not marker_scene:
		return
	var marker = marker_scene.instantiate()
	get_tree().current_scene.add_child(marker)
	var player = get_tree().get_first_node_in_group("Player")
	if player and is_instance_valid(player):
		marker.global_position = player.global_position
	var icon_tex = _get_icon_texture(entry.node, entry.type)
	marker.setup(entry.node, icon_tex, entry.elite)
	_markers[id] = marker

func _get_icon_texture(node: Node2D, type: String) -> Texture2D:
	var sprite = node.get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = _find_sprite(node)
	if sprite and sprite.texture:
		return sprite.texture
	return null

func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var found = _find_sprite(child)
		if found:
			return found
	return null
