extends Weapon
class_name Boomerang

@export var amount: = 1
@export var spread: = 14.0
@export var max_distance: = 260.0
@export var return_speed: = 340.0
@export var throw_interval: = 0.15

func activate(source, target, scene_tree):
	if source == null:
		return
	if scene_tree != null and scene_tree.paused:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	var count: = int(amount)
	for i in range(count):
		if not is_instance_valid(source):
			return
		var real_target = target
		if real_target == null or not is_instance_valid(real_target):
			real_target = _find_nearest_enemy(scene_tree, source)
		_throw(source, real_target, scene_tree, i)
		if i < count - 1:
			await scene_tree.create_timer(throw_interval).timeout

func _throw(source, target, scene_tree, index: int):
	if projectile_node == null:
		return
	var projectile = projectile_node.instantiate()
	var dir: = Vector2.RIGHT
	if target != null and is_instance_valid(target) and target is Node2D:
		dir = (target.global_position - source.global_position).normalized()
	else:
		dir = Vector2.from_angle(randf() * TAU)
	var total: float = max(1, int(amount))
	var offset: = (index - (total - 1) / 2.0) * spread
	dir = dir.rotated(deg_to_rad(offset))
	projectile.damage = damage
	projectile.speed = speed
	projectile.source = source
	projectile.direction = dir
	projectile.position = source.global_position
	if "return_speed" in projectile:
		projectile.return_speed = return_speed
	if "max_distance" in projectile:
		projectile.max_distance = max_distance
	var sprite = projectile.find_child("Sprite2D")
	if sprite != null and texture != null:
		sprite.texture = texture
	scene_tree.current_scene.add_child(projectile)

func _find_nearest_enemy(scene_tree: SceneTree, from: Node2D) -> Node2D:
	var radius = _attack_radius(from)
	var r2 = radius * radius
	var from_position = from.global_position
	var best: Node2D = null
	var best_distance: = INF
	for enemy in scene_tree.get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var dist = from_position.distance_squared_to(enemy.global_position)
		if dist > r2:
			continue
		if dist < best_distance:
			best_distance = dist
			best = enemy
	return best

func _attack_radius(source: Node2D) -> float:
	if is_instance_valid(source) and "area" in source:
		return + source.area
	return 0

func upgrade_item():
	if max_level_reached():
		try_evolve()
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
	if "return_speed" in upgrade:
		return_speed += upgrade.return_speed
	if "max_distance" in upgrade:
		max_distance += upgrade.max_distance
	level += 1
