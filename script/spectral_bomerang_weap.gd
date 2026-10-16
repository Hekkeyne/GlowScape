extends Weapon
class_name SpectralSplitterang

@export var amount := 1
@export var spread := 14.0
@export var max_distance := 280.0
@export var return_speed := 380.0
@export var split_count := 3
@export var fan_angle := 35.0
@export var child_damage_multiplier := 0.7
@export var throw_interval := 0.08

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree != null and scene_tree.paused:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	var used_targets: Array = []
	var count := int(amount)
	for i in range(count):
		if not is_instance_valid(source):
			return
		var real_target = _find_nearest_enemy(scene_tree, source, used_targets)
		if real_target != null:
			used_targets.append(real_target)
		_throw(source, real_target, scene_tree, i)
		if i < count - 1:
			await scene_tree.create_timer(throw_interval).timeout

func _throw(source, target, scene_tree, index: int):
	if projectile_node == null:
		return
	var projectile = projectile_node.instantiate()
	var dir := Vector2.RIGHT
	if target != null and is_instance_valid(target) and target is Node2D:
		dir = (target.global_position - source.global_position).normalized()
	else:
		dir = Vector2.from_angle(randf() * TAU)
	var total: float = max(1, int(amount))
	var offset := (index - (total - 1) / 2.0) * spread
	dir = dir.rotated(deg_to_rad(offset))
	projectile.damage = damage
	projectile.speed = speed
	projectile.source = source
	projectile.direction = dir
	if "return_speed" in projectile:
		projectile.return_speed = return_speed
	if "max_distance" in projectile:
		projectile.max_distance = max_distance
	if "split_count" in projectile:
		projectile.split_count = split_count
	if "fan_angle" in projectile:
		projectile.fan_angle = fan_angle
	if "child_damage_multiplier" in projectile:
		projectile.child_damage_multiplier = child_damage_multiplier
	if "split_scene" in projectile:
		projectile.split_scene = projectile_node
	var sprite = projectile.get_node_or_null("Sprite2D")
	if sprite != null and texture != null:
		sprite.texture = texture
	scene_tree.current_scene.add_child(projectile)
	projectile.global_position = source.global_position

func _find_nearest_enemy(scene_tree: SceneTree, source: Node2D, exclude: Array = []) -> Node2D:
	var radius = _attack_radius(source)
	var r2 = radius * radius
	var from_position = source.global_position
	var best: Node2D = null
	var best_distance := INF
	for enemy in scene_tree.get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if exclude.has(enemy):
			continue
		var dist = from_position.distance_squared_to(enemy.global_position)
		if dist > r2:
			continue
		if dist < best_distance:
			best_distance = dist
			best = enemy
	if best == null and not exclude.is_empty():
		return _find_nearest_enemy(scene_tree, source)
	return best

func _attack_radius(source: Node2D) -> float:
	if is_instance_valid(source) and "area" in source:
		return 250.0 + source.area
	return 250.0

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "speed" in upgrade:
		speed += upgrade.speed
	if "amount" in upgrade:
		amount += upgrade.amount
	level += 1
	max_distance = 260.0 + level * 20.0
	return_speed = 360.0 + level * 15.0
	split_count = min(5, 3 + int(level / 3))
