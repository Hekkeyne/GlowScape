extends Weapon
class_name Turret

@export var max_turrets := 2
@export var turret_types: Array[String] = ["mg"]
@export var turret_lifetime := 10.0
@export var range_bonus := 60.0
@export var turret_scene: PackedScene
@export var bullet_scene: PackedScene
@export var rocket_scene: PackedScene
@export var turret_lightning_texture: Texture2D
@export var turret_rocket_texture: Texture2D
@export var zap_texture: Texture2D
@export var explosion_texture: Texture2D
@export var bullet_texture: Texture2D
@export var rocket_texture: Texture2D
@export var orbit_radius := 60.0
@export var orbit_speed := 90.0

var active_turrets: Array = []
var player_ref: Node2D = null

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree != null and scene_tree.paused:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if turret_types.is_empty() or turret_scene == null:
		return
	player_ref = source
	active_turrets = active_turrets.filter(func(t): return is_instance_valid(t))
	var missing := max_turrets - active_turrets.size()
	for i in range(missing):
		var type = turret_types.pick_random()
		_spawn_turret(source, scene_tree, type)
	_redistribute_turrets()

func update(_delta: float) -> void:
	var r = _attack_radius()
	for t in active_turrets:
		if is_instance_valid(t) and "attack_range" in t:
			t.attack_range = r + range_bonus

func reset():
	active_turrets.clear()
	player_ref = null

func _spawn_turret(source, scene_tree, type):
	var turret = turret_scene.instantiate()
	turret.turret_type = type
	turret.damage = damage
	turret.source = source
	turret.attack_range = _attack_radius() + range_bonus
	turret.bullet_scene = bullet_scene
	turret.rocket_scene = rocket_scene
	turret.zap_texture = zap_texture
	turret.explosion_texture = explosion_texture
	turret.bullet_texture = bullet_texture
	turret.rocket_texture = rocket_texture
	turret.lifetime = _get_group_lifetime()
	turret.orbit_radius = orbit_radius
	turret.orbit_speed = orbit_speed
	turret.orbit_angle = -90.0
	if is_instance_valid(source):
		var a = deg_to_rad(turret.orbit_angle)
		turret.global_position = source.global_position + orbit_radius * Vector2(cos(a), sin(a))
	var sprite = turret.get_node_or_null("Sprite2D")
	if sprite != null:
		match type:
			"lightning":
				if turret_lightning_texture != null:
					sprite.texture = turret_lightning_texture
			"rocket":
				if turret_rocket_texture != null:
					sprite.texture = turret_rocket_texture
			_:
				if texture != null:
					sprite.texture = texture
	active_turrets.append(turret)
	scene_tree.current_scene.add_child(turret)

func _get_group_lifetime() -> float:
	var group_life = turret_lifetime
	for t in active_turrets:
		if is_instance_valid(t) and "lifetime" in t:
			group_life = min(group_life, t.lifetime)
	return group_life

func _redistribute_turrets():
	var alive := []
	for t in active_turrets:
		if is_instance_valid(t):
			alive.append(t)
	active_turrets = alive
	if alive.is_empty():
		return
	var count = alive.size()
	var angle_step = 360.0 / count
	var base_angle = -90.0
	if "orbit_angle" in alive[0]:
		base_angle = alive[0].orbit_angle
	for i in range(count):
		if "orbit_angle" in alive[i]:
			alive[i].orbit_angle = base_angle + i * angle_step

func _attack_radius() -> float:
	if is_instance_valid(player_ref) and "area" in player_ref:
		return player_ref.area
	return 0

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
	if "amount" in upgrade:
		max_turrets += upgrade.amount
	level += 1
	turret_lifetime = 8.0 + level * 1.0
	range_bonus = 40.0 + level * 10.0
	_redistribute_turrets()
