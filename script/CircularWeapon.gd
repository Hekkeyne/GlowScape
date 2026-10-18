extends Weapon
class_name Circular

@export var angular_speed = 20
@export var radius = 20
@export var amount = 1
var projectile_ref: Array[Area2D] = []
var angle: float

func activate(source, _target, _scene_tree):
	reset()
	for i in range(amount):
		add_to_player(source)

func add_to_player(source):
	var projectile = projectile_node.instantiate()
	projectile.speed = 0
	projectile.damage = damage
	projectile.source = source
	projectile.hide()
	var sprite = projectile.find_child("Sprite2D")
	if sprite:
		sprite.texture = texture
	projectile_ref.append(projectile)
	source.call_deferred("add_child", projectile)

func update(delta):
	angle += angular_speed * delta
	for i in range(projectile_ref.size() - 1, -1, -1):
		var proj = projectile_ref[i]
		if not is_instance_valid(proj):
			projectile_ref.remove_at(i)
			continue
		var offset = i * (360.0 / amount)
		proj.position = radius * Vector2(cos(deg_to_rad(angle + offset)), sin(deg_to_rad(angle + offset)))
		proj.show()
		proj.rotation_degrees += 1000 * delta

func reset():
	for i in range(projectile_ref.size() - 1, -1, -1):
		var proj = projectile_ref.pop_back()
		if is_instance_valid(proj):
			proj.queue_free()
	projectile_ref.clear()

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	damage += upgrade.damage
	amount += upgrade.amount
	angular_speed += upgrade.angular_speed
	level += 1
	
