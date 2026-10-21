extends Weapon
class_name BlackHoleWeapon

@export var amount: int = 1
@export var hole_scene: PackedScene
@export var missile_scene: PackedScene
@export_range(100.0, 600.0, 25.0) var cluster_radius: float = 250.0
@export var evolved: bool = false
@export var core_texture: Texture2D
@export var rim_texture: Texture2D
@export var swirl_texture: Texture2D
@export var field_texture: Texture2D
@export var missile_texture: Texture2D

var bonus_radius: float = 0.0
var bonus_duration: float = 0.0
var bonus_pull: float = 0.0
var bonus_knock: float = 0.0

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	if hole_scene == null:
		return
	var pool = _targets_in_range(source, scene_tree)
	if pool.is_empty():
		return
	var src_pos = source.global_position
	pool.sort_custom( func(a, b): return a.global_position.distance_squared_to(src_pos) < b.global_position.distance_squared_to(src_pos))
	var working: Array = pool.duplicate()
	var centers: Array = []
	var ring_angle: float = randf() * TAU
	for i in range(amount):
		var pick: Node2D = null
		for e in working:
			if not is_instance_valid(e):
				continue
			pick = e
			break
		var center: Vector2
		if pick != null:
			center = pick.global_position
		else:
			center = _ring_center(centers, ring_angle)
		centers.append(center)
		var hole = hole_scene.instantiate()
		hole.explode_damage = damage
		hole.target_point = center
		hole.source = source
		hole.enable_missiles = evolved
		hole.missile_scene = missile_scene
		hole.missile_texture = missile_texture
		hole.missile_damage = damage * 0.5
		hole.core_texture = core_texture
		hole.rim_texture = rim_texture
		hole.swirl_texture = swirl_texture
		hole.field_texture = field_texture
		hole.pull_radius += bonus_radius
		hole.duration += bonus_duration
		hole.pull_strength += bonus_pull
		hole.knock_strength += bonus_knock
		scene_tree.current_scene.add_child(hole)
		hole.global_position = source.global_position
		hole.add_child(HoleGhostTracker.new())
		working = _filter_pool(working, center)

func _ring_center(centers: Array, ring_angle: float) -> Vector2:
	var anchor: Vector2 = centers[0]
	var min_dist = cluster_radius * 0.7
	var min_d2 = min_dist * min_dist
	for attempt in range(6):
		var ang = ring_angle + attempt * 2.39996
		var candidate = anchor + Vector2.from_angle(ang) * cluster_radius
		var ok = true
		for c in centers:
			if candidate.distance_squared_to(c) < min_d2:
				ok = false
				break
		if ok:
			return candidate
	return anchor + Vector2.from_angle(ring_angle) * cluster_radius

func _filter_pool(pool: Array, center: Vector2) -> Array:
	var r2 = cluster_radius * cluster_radius
	var result: Array = []
	for e in pool:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_squared_to(center) > r2:
			result.append(e)
	return result

func _targets_in_range(source: Node2D, tree: SceneTree) -> Array:
	var result: Array = []
	var radius = _attack_radius(source)
	var r2 = radius * radius
	var src_pos = source.global_position
	for node in tree.get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D:
			continue
		if node.global_position.distance_squared_to(src_pos) <= r2:
			result.append(node)
	return result

func _attack_radius(source: Node2D) -> float:
	if is_instance_valid(source) and "area" in source:
		return source.area
	return 0

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "amount" in upgrade:
		amount += upgrade.amount
	if "damage" in upgrade:
		damage += upgrade.damage
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "holes" in upgrade:
		amount += upgrade.holes
	if "radius" in upgrade:
		bonus_radius += upgrade.radius
	if "duration" in upgrade:
		bonus_duration += upgrade.duration
	if "pull" in upgrade:
		bonus_pull += upgrade.pull
	if "knock" in upgrade:
		bonus_knock += upgrade.knock
	level += 1
