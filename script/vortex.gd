extends Weapon
class_name VortexWeapon

@export var vortex_count: int = 1
@export var spread_angle: float = 15.0
@export var max_enemies: int = 3
@export var lifetime: float = 3.0
@export var max_scale_multiplier: float = 3.0

var bonus_max_enemies: int = 0
var bonus_lifetime: float = 0.0
var bonus_speed: float = 0.0

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	if projectile_node == null:
		return
	var target_enemy = _find_nearest_enemy(scene_tree, source)
	if target_enemy == null:
		return
	var base_dir = (target_enemy.global_position - source.global_position).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	for i in range(vortex_count):
		_throw_vortex(source, base_dir, scene_tree, i)

func _throw_vortex(source: Node2D, base_dir: Vector2, scene_tree: SceneTree, index: int):
	var vortex = projectile_node.instantiate()
	var total = max(1, vortex_count)
	var offset_deg = (index - (total - 1) / 2.0) * spread_angle
	var dir = base_dir.rotated(deg_to_rad(offset_deg))
	vortex.damage = damage
	vortex.speed = speed + bonus_speed
	vortex.source = source
	vortex.direction = dir
	vortex.max_enemies = max_enemies + bonus_max_enemies
	vortex.lifetime = lifetime + bonus_lifetime
	vortex.max_scale_multiplier = max_scale_multiplier
	vortex.texture_override = texture
	scene_tree.current_scene.add_child(vortex)
	vortex.global_position = source.global_position
	if vortex.has_method("init_position"):
		vortex.init_position()

func _find_nearest_enemy(scene_tree: SceneTree, from: Node2D) -> Node2D:
	var radius = _attack_radius(from)
	var r2 = radius * radius
	var from_pos = from.global_position
	var best: Node2D = null
	var best_dist = INF
	for enemy in scene_tree.get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if "is_dying" in enemy and enemy.is_dying:
			continue
		var dist = from_pos.distance_squared_to(enemy.global_position)
		if dist > r2:
			continue
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

func _attack_radius(source: Node2D) -> float:
	if is_instance_valid(source) and "area" in source:
		return source.area
	return 0.0

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
	if "amount" in upgrade:
		vortex_count += upgrade.amount
	if "max_enemies" in upgrade:
		bonus_max_enemies += upgrade.max_enemies
	if "lifetime" in upgrade:
		bonus_lifetime += upgrade.lifetime
	if "speed_bonus" in upgrade:
		bonus_speed += upgrade.speed_bonus
	level += 1
