extends Weapon
class_name HolySword

@export var sword_scene: PackedScene
@export var sword_count: int = 1
@export var sfx_hit: Array[AudioStream] = []
@export var knockback: float = 150.0
@export var orbit_margin: float = 40.0
@export var orbit_speed: float = 0.04
@export var fly_speed: float = 500.0
@export var fly_accel: float = 1200.0
@export var fly_max_speed: float = 1600.0
@export var aim_time: float = 0.5
@export var charge_time: float = 0.45
@export var charge_spin_speed: float = 18.0
@export var disc_spin_speed: float = 28.0
@export var emerge_time: float = 0.25
@export var overshoot: float = 60.0
@export var shake_strength: float = 0.08
@export var sprite_angle_offset: float = 90.0
@export var disc_texture: Texture2D = null

var active_swords: Array = []
var player_ref: Node2D = null

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	player_ref = source
	active_swords = active_swords.filter(func(s): return is_instance_valid(s))
	var missing = sword_count - active_swords.size()
	for i in range(missing):
		_spawn_sword(source, scene_tree)

func update(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		var tree = Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		player_ref = tree.get_first_node_in_group("Player")
	var r = _attack_radius()
	for s in active_swords:
		if not is_instance_valid(s):
			continue
		s.damage = damage
		s.cooldown = cooldown
		s.search_radius = r
		s.player_ref = player_ref
		s.bullet_texture = texture
		s.disc_texture = disc_texture
		s.sfx_hit = sfx_hit
		s.knockback = knockback
		s.orbit_margin = orbit_margin
		s.orbit_speed = orbit_speed
		s.fly_speed = fly_speed
		s.fly_accel = fly_accel
		s.fly_max_speed = fly_max_speed
		s.aim_time = aim_time
		s.charge_time = charge_time
		s.charge_spin_speed = charge_spin_speed
		s.disc_spin_speed = disc_spin_speed
		s.emerge_time = emerge_time
		s.overshoot = overshoot
		s.shake_strength = shake_strength
		s.sprite_angle_offset = sprite_angle_offset

func reset():
	for s in active_swords:
		if is_instance_valid(s):
			s.queue_free()
	active_swords.clear()
	player_ref = null

func _spawn_sword(source: Node2D, scene_tree: SceneTree) -> void:
	if sword_scene == null:
		return
	var sword = sword_scene.instantiate()
	sword.damage = damage
	sword.cooldown = cooldown
	sword.search_radius = _attack_radius()
	sword.player_ref = source
	sword.bullet_texture = texture
	sword.disc_texture = disc_texture
	sword.sfx_hit = sfx_hit
	sword.knockback = knockback
	sword.orbit_margin = orbit_margin
	sword.orbit_speed = orbit_speed
	sword.fly_speed = fly_speed
	sword.fly_accel = fly_accel
	sword.fly_max_speed = fly_max_speed
	sword.aim_time = aim_time
	sword.charge_time = charge_time
	sword.charge_spin_speed = charge_spin_speed
	sword.disc_spin_speed = disc_spin_speed
	sword.emerge_time = emerge_time
	sword.overshoot = overshoot
	sword.shake_strength = shake_strength
	sword.sprite_angle_offset = sprite_angle_offset
	scene_tree.current_scene.add_child(sword)
	active_swords.append(sword)

func _attack_radius() -> float:
	if is_instance_valid(player_ref) and "area" in player_ref:
		return player_ref.area
	return 100.0

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
		fly_speed += upgrade.speed
	if "amount" in upgrade:
		sword_count += upgrade.amount
	level += 1
