extends Node2D

@export var marker_scene: PackedScene
@export var update_interval: float = 0.05

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
	for dummy in get_tree().get_nodes_in_group("RemotePlayer"):
		if not is_instance_valid(dummy):
			continue
		var id = dummy.peer_id if "peer_id" in dummy else dummy.get_instance_id()
		seen[id] = true
		if not _markers.has(id):
			_spawn_marker(id, dummy)
		elif is_instance_valid(_markers[id]):
			_markers[id].target = dummy
			_markers[id].update_marker()
	var to_remove: Array = []
	for id in _markers:
		if not seen.has(id):
			to_remove.append(id)
	for id in to_remove:
		if is_instance_valid(_markers[id]):
			_markers[id].queue_free()
		_markers.erase(id)

func _spawn_marker(id: int, dummy: Node2D) -> void :
	if not marker_scene:
		return
	var marker = marker_scene.instantiate()
	get_tree().current_scene.add_child(marker)
	var player = get_tree().get_first_node_in_group("Player")
	if player and is_instance_valid(player):
		marker.global_position = player.global_position
	var skin_tex = _get_skin_texture(dummy)
	marker.setup(dummy, skin_tex)
	_markers[id] = marker

func _get_skin_texture(dummy: Node2D) -> Texture2D:
	if dummy.peer_id <= 0:
		return null
	var chars = Net.peer_chars.get(dummy.peer_id, {})
	var tex_path = str(chars.get("tex", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		return load(tex_path)
	var sprite = dummy.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		return sprite.texture
	return null
