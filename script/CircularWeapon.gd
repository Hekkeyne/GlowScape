extends Weapon
class_name Circular

@export var angular_speed=20
@export var radius = 20
@export var amount = 1
var projectile_ref : Array[Area2D]
var angle:float

func activate (source, _target, _scene_tree):
	reset()
	for i in range(amount):
		add_to_player(source)

func add_to_player(source):
	var projectile = projectile_node.instantiate()
	projectile.speed = 0
	projectile.damage = damage
	projectile.source = source
	projectile.hide()
	projectile.find_child("Sprite2D").texture=texture
	projectile_ref.append(projectile)
	source.call_deferred("add_child",projectile)

func update(delta):
	angle+=angular_speed*delta
	for i in range (projectile_ref.size()):
		var offset = i * (360.0/amount)
		projectile_ref[i].position = radius*Vector2(cos(deg_to_rad(angle+offset)),sin(deg_to_rad(angle+offset)))
		projectile_ref[i].show()
		projectile_ref[i].rotation_degrees += 1000 * delta
	

func reset():
	for i in range (projectile_ref.size()):
		projectile_ref.pop_front().queue_free()

func upgrade_item():
	if max_level_reached():
		slot.item=evolution
		return 
	if not is_upgradable():
		return
	var upgrade = upgrades[level-1]
	damage +=upgrade.damage
	amount+=upgrade.amount
	angular_speed+=upgrade.angular_speed
	level+=1
