extends Weapon
class_name OrbitalStorm
@export var angular_speed: = 45.0
@export var radius: = 42.0
@export var amount: = 2
@export var chain_texture: Texture2D
@export var chain_damage_multiplier: = 0.65
@export var chain_jumps: = 3
@export var chain_radius: = 150.0
@export var chain_cooldown: = 0.35
var projectile_ref: Array = []
var angle: = 0.0

func activate(source, _target, scene_tree):
	if source == null:
		return
	if scene_tree != null and scene_tree.paused:
		return
	reset()
	for i in range(int(amount)):
		add_to_player(source)


func add_to_player(source):
	if projectile_node == null:
		push_warning("OrbitalStorm: projectile_node не задан")
		return
	var projectile = projectile_node.instantiate()
	projectile.speed = 0
	projectile.damage = damage
	projectile.source = source
	projectile.hide()
	var sprite = projectile.find_child("Sprite2D")
	if sprite != null and texture != null:
		sprite.texture = texture
	_apply_chain_settings(projectile)
	projectile_ref.append(projectile)
	source.call_deferred("add_child", projectile)

func update(delta):
	angle += angular_speed * delta
	var count = max(1, int(amount))
	for i in range(projectile_ref.size()):
		var projectile = projectile_ref[i]
		if not is_instance_valid(projectile):
			continue
		var offset = i * (360.0 / count)
		var a = deg_to_rad(angle + offset)
		projectile.position = radius * Vector2(cos(a), sin(a))
		projectile.show()
		projectile.rotation_degrees += 900.0 * delta
		_apply_chain_settings(projectile)

func reset():
	for projectile in projectile_ref:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectile_ref.clear()

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "amount" in upgrade:
		amount += upgrade.amount
	if "angular_speed" in upgrade:
		angular_speed += upgrade.angular_speed
	if "radius" in upgrade:
		radius += upgrade.radius
	level += 1
	chain_jumps = 2 + int(level / 2)
	chain_radius = 130.0 + level * 10.0
	chain_damage_multiplier = 0.6 + level * 0.03
	for projectile in projectile_ref:
		if is_instance_valid(projectile):
			_apply_chain_settings(projectile)


func _apply_chain_settings(projectile):
	if projectile == null:
		return
	if "chain_damage" in projectile:
		projectile.chain_damage = max(1.0, damage * chain_damage_multiplier)
	if "chain_jumps" in projectile:
		projectile.chain_jumps = chain_jumps
	if "chain_radius" in projectile:
		projectile.chain_radius = chain_radius
	if "chain_cooldown" in projectile:
		projectile.chain_cooldown = chain_cooldown
	if "chain_texture" in projectile:
		projectile.chain_texture = chain_texture
