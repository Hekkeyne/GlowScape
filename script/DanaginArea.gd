extends Weapon
class_name DamaginArea

@export var angular_speed: float = 10
@export_range(0, 100, 1) var area_percent: float = 50

var angle: float
var projectile_ref
var player_ref: Node2D = null
var pulse_t: float = 1.0

const BASE_RADIUS: float = 32.0

func activate(source, _target, _scene_tree):
	reset_collision()
	pulse_t = 0.0
	if not is_instance_valid(projectile_ref):
		add_to_player(source)

func update(delta):
	angle += angular_speed * delta
	if not is_instance_valid(projectile_ref):
		return
	projectile_ref.rotation_degrees = angle
	projectile_ref.damage = damage
	if pulse_t < 1.0:
		pulse_t = minf(pulse_t + delta / 0.5, 1.0)
	var base = _zone_scale()
	var pulse = 1.0 + 0.1 * sin(pulse_t * PI * 2.0) * pow(1.0 - pulse_t, 2.0)
	projectile_ref.scale = Vector2(base * pulse, base * pulse)

func reset():
	if is_instance_valid(projectile_ref):
		projectile_ref.queue_free()
	projectile_ref = null
	player_ref = null

func add_to_player(source):
	player_ref = source
	var projectile = projectile_node.instantiate()
	projectile.speed = 0
	projectile.damage = damage
	projectile.source = source
	projectile.z_index = 0
	var sprite = projectile.get_node_or_null("Sprite2D")
	if sprite and texture:
		sprite.texture = texture
	var collision = projectile.get_node_or_null("CollisionShape2D")
	if collision and collision.shape:
		collision.shape.radius = BASE_RADIUS
	var s = _zone_scale()
	projectile.scale = Vector2(s, s)
	projectile_ref = projectile
	source.call_deferred("add_child", projectile)

func reset_collision():
	if is_instance_valid(projectile_ref):
		var collision = projectile_ref.get_node_or_null("CollisionShape2D")
		if collision:
			collision.disabled = true
			collision.disabled = false

func _zone_scale() -> float:
	var radius: float = 0
	if is_instance_valid(player_ref) and "area" in player_ref:
		radius = player_ref.area
	return radius * (area_percent / 100.0) / BASE_RADIUS

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "area" in upgrade:
		area_percent += upgrade.area
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "damage" in upgrade:
		damage += upgrade.damage
	level += 1
