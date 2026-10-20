extends Weapon
class_name StarSword
@export var blade_scene: PackedScene
@export var base_distance: float = 150.0
@export var area_multiplier: float = 0.55
@export var attack_radius_mult: float = 2.5
@export var attack_margin: float = 120.0
@export var follow_stiffness: float = 80.0
@export var follow_damping: float = 12.0
@export var side_swing_speed: float = 8.0
@export var sprite_forward_offset: float = 0.0
@export var max_screen_margin: float = 25.0
@export var shake_strength: float = 0.35
@export var knockback: float = 120.0
@export var disc_texture: Texture2D = null
@export var spin_star_count: int = 8
@export var spin_star_scene: PackedScene
@export var spin_star_textures: Array[Texture2D] = []
@export var base_bounce_star_count: int = 4
@export var max_bounce_star_count: int = 12
@export var bounce_star_scene: PackedScene
@export var bounce_star_textures: Array[Texture2D] = []
var active_blade = null
var player_ref: Node2D = null
func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	player_ref = source
	if not is_instance_valid(active_blade):
		_spawn_blade(source, scene_tree)
func update(delta: float) -> void:
	if not is_instance_valid(player_ref):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		player_ref = tree.get_first_node_in_group("Player")
	if is_instance_valid(active_blade):
		_push_to_blade(active_blade)
func reset():
	if is_instance_valid(active_blade):
		active_blade.queue_free()
	active_blade = null
	player_ref = null
func _push_to_blade(blade) -> void:
	blade.set("damage", damage)
	blade.set("cooldown", cooldown)
	blade.set("attack_radius", _attack_radius())
	blade.set("attack_margin", attack_margin)
	blade.set("player_ref", player_ref)
	blade.set("bullet_texture", texture)
	blade.set("disc_texture", disc_texture)
	blade.set("spin_star_count", spin_star_count)
	blade.set("spin_star_scene", spin_star_scene)
	blade.set("spin_star_textures", spin_star_textures)
	blade.set("base_bounce_star_count", base_bounce_star_count)
	blade.set("max_bounce_star_count", max_bounce_star_count)
	blade.set("bounce_star_scene", bounce_star_scene)
	blade.set("bounce_star_textures", bounce_star_textures)
	blade.set("base_distance", base_distance)
	blade.set("area_multiplier", area_multiplier)
	blade.set("follow_stiffness", follow_stiffness)
	blade.set("follow_damping", follow_damping)
	blade.set("side_swing_speed", side_swing_speed)
	blade.set("sprite_forward_offset", sprite_forward_offset)
	blade.set("max_screen_margin", max_screen_margin)
	blade.set("shake_strength", shake_strength)
	blade.set("knockback", knockback)
func _spawn_blade(source: Node2D, scene_tree: SceneTree) -> void:
	if blade_scene == null:
		return
	var blade: Node2D = blade_scene.instantiate() as Node2D
	if blade == null:
		return
	blade.set("player_ref", source)
	_push_to_blade(blade)
	scene_tree.current_scene.add_child(blade)
	active_blade = blade
func _attack_radius() -> float:
	if is_instance_valid(player_ref) and "area" in player_ref:
		return float(player_ref.area) * attack_radius_mult
	return 100.0
func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade: Upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += float(upgrade.damage)
	if "cooldown" in upgrade:
		cooldown += float(upgrade.cooldown)
	level += 1
