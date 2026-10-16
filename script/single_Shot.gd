extends Weapon
class_name single_Shot

@export var sfx_shoot: AudioStream = load("res://resourse/audio/LazerFire1.wav")
@export var split_on_hit: bool = false

func shoot(source, target, scene_tree):
	if target == null:
		return
	var player = AudioStreamPlayer2D.new()
	player.stream = sfx_shoot
	player.volume_db = -15
	player.pitch_scale = randf_range(0.7, 1.2)
	player.position = source.position
	scene_tree.current_scene.add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
	var projectiles = projectile_node.instantiate()
	projectiles.position = source.position
	projectiles.damage = damage
	projectiles.speed = speed
	projectiles.source = source
	projectiles.direction = (target.position - source.position).normalized()
	projectiles.split_on_hit = split_on_hit
	projectiles.projectile_scene = projectile_node
	scene_tree.current_scene.add_child(projectiles)
	projectiles.bullet_texture = texture

func activate(source, target, scene_tree):
	shoot(source, target, scene_tree)

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	damage += upgrade.damage
	cooldown += upgrade.cooldown
	speed += upgrade.speed
	level += 1
