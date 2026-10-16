extends Weapon
class_name ParasiteSwarm
@export var amount := 2
@export var jumps := 3
@export var jump_radius := 260.0
@export var jump_speed := 520.0
@export var jump_delay := 0.25
@export var split_chance := 0.35
@export var small_bug_texture: Texture2D

func activate(source, _target, scene_tree):
	if source == null:
		return
	if scene_tree != null and scene_tree.paused:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	var enemies = scene_tree.get_nodes_in_group("Enemy")
	if enemies.size() == 0:
		return
	for i in range(int(amount)):
		var enemy = enemies.pick_random()
		if enemy == null or not is_instance_valid(enemy):
			continue
		_spawn_bug(source, enemy, scene_tree, false)

func _spawn_bug(source, target_enemy, scene_tree, is_small: bool):
	if projectile_node == null:
		return
	var bug = projectile_node.instantiate()
	bug.damage = damage * (0.5 if is_small else 1.0)
	bug.source = source
	bug.current_target = target_enemy
	bug.is_small = is_small
	bug.jumps_left = 1 if is_small else jumps
	bug.jump_radius = jump_radius
	bug.jump_speed = jump_speed
	bug.jump_delay = jump_delay
	bug.split_chance = 0.0 if is_small else split_chance
	bug.bug_scene = projectile_node
	if "small_bug_texture" in bug:
		bug.small_bug_texture = small_bug_texture
	bug.global_position = target_enemy.global_position
	if is_small:
		bug.scale = Vector2(0.6, 0.6)
	var sprite = bug.find_child("Sprite2D")
	if sprite != null:
		if is_small and small_bug_texture != null:
			sprite.texture = small_bug_texture
		elif texture != null:
			sprite.texture = texture
	scene_tree.current_scene.add_child(bug)

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
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
	level += 1
	jumps = 2 + int(level / 2)
	jump_radius = 220.0 + level * 15.0
	split_chance = min(0.6, 0.25 + level * 0.05)
