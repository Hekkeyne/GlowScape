extends PanelContainer

var enabled: bool = true

@export var item : Weapon:
	set(value):
		if item!=null and item.has_method("reset"):
			item.reset()
		item=value
		if item == null:
			$TextureRect.texture=preload("res://sprites/ITEM_placeholder.png")
			visible = true
			return
		$TextureRect.texture=value.icon
		$cooldown.wait_time=value.cooldown
		item.slot=self

func set_enabled(v: bool) -> void:
	enabled = v
	set_process(v)
	set_physics_process(v)

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if item!=null and item.has_method("update"):
		item.update(delta)

func _on_cooldown_timeout() -> void:
	if not enabled or not item:
		return
	var player = get_tree().get_first_node_in_group("Player")
	if player == null or not is_instance_valid(player):
		return
	var target = _find_nearest_enemy(player)
	if target == null:
		return
	$cooldown.wait_time=item.cooldown
	item.activate(player, target, get_tree())

func _find_nearest_enemy(player: Node2D) -> Node2D:
	var best_dist = INF
	var best_node = null
	var from_pos = player.global_position
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(node):
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var dist = from_pos.distance_squared_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best_node = node
	var detection_radius = 250.0 + (player.area if "area" in player else 0.0)
	if best_dist <= pow(detection_radius, 2):
		return best_node
	return null
