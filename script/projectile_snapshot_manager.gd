extends Node2D

@export var snapshot_interval: float = 0.05
var _timer: float = 0.0
var _next_net_id: int = 1

func _process(delta: float) -> void :
	if not multiplayer.has_multiplayer_peer() or not Net.is_host:
		return
	_timer += delta
	if _timer < snapshot_interval:
		return
	_timer = 0.0
	_assign_ids()
	_send_snapshot()

func _assign_ids() -> void :
	for proj in get_tree().get_nodes_in_group("Projectile"):
		if not is_instance_valid(proj):
			continue
		if not ("net_id" in proj):
			continue
		if proj.net_id <= 0:
			proj.net_id = _next_net_id
			_next_net_id += 1

func _send_snapshot() -> void :
	var data: Array = []
	for proj in get_tree().get_nodes_in_group("Projectile"):
		if not is_instance_valid(proj):
			continue
		if not ("net_id" in proj) or proj.net_id <= 0:
			continue
		var entry: Dictionary = {
			"id": proj.net_id, 
			"pos": proj.global_position, 
			"rot": proj.rotation, 
			"tex": _get_texture_path(proj)
		}
		data.append(entry)
	Net.send_projectile_snapshot(data)

func _get_texture_path(proj: Node) -> String:
	var spr = proj.get_node_or_null("Sprite2D")
	if spr == null:
		spr = _find_sprite(proj)
	if spr and spr.texture and spr.texture.resource_path != "":
		return spr.texture.resource_path
	return ""

func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var found = _find_sprite(child)
		if found:
			return found
	return null
