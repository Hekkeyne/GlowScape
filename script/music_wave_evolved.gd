extends Weapon
class_name Requiem

@export var angular_speed: float = 10
@export_range(0, 100, 1) var area_percent: float = 50
@export var note_scene: PackedScene
@export var note_textures: Array[Texture2D] = []
@export var notes_amount: = 6
@export var note_speed: = 260.0
@export var note_damage_multiplier: = 0.6
@export var big_beat_every: = 4
@export var big_beat_notes_bonus: = 6
@export var big_beat_wave_damage_multiplier: = 1.5
@export var big_beat_knockback: = 220.0

var angle: float
var projectile_ref
var player_ref: Node2D = null
var _beat: = 0
var _spiral_offset: = 0.0
var pulse_t: float = 1.0
var pulse_amp: float = 0.0

const BASE_RADIUS: float = 32.0

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree != null and scene_tree.paused:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	player_ref = source
	_beat += 1
	var is_big: = (_beat % big_beat_every) == 0
	reset_collision()
	pulse_t = 0.0
	pulse_amp = 0.25 if is_big else 0.1
	if not is_instance_valid(projectile_ref):
		add_to_player(source)
	_spiral_offset += 15.0
	_spawn_notes(source, scene_tree, is_big)
	if is_big:
		_big_beat_wave(source)

func update(delta):
	angle += angular_speed * delta
	if not is_instance_valid(projectile_ref):
		return
	projectile_ref.rotation_degrees = angle
	projectile_ref.damage = damage
	if pulse_t < 1.0:
		pulse_t = minf(pulse_t + delta / 0.5, 1.0)
	var base = _zone_scale()
	var pulse = 1.0 + pulse_amp * sin(pulse_t * PI * 2.0) * pow(1.0 - pulse_t, 2.0)
	projectile_ref.scale = Vector2(base * pulse, base * pulse)

func reset():
	if is_instance_valid(projectile_ref):
		projectile_ref.queue_free()
	projectile_ref = null
	player_ref = null

func add_to_player(source):
	if projectile_node == null:
		return
	player_ref = source
	var projectile = projectile_node.instantiate()
	projectile.speed = 0
	projectile.damage = damage
	projectile.source = source
	projectile.z_index = 0
	var sprite = projectile.get_node_or_null("Sprite2D")
	if sprite != null and texture != null:
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

func _spawn_notes(source, scene_tree, is_big: bool):
	if note_scene == null:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	var count: = notes_amount + (big_beat_notes_bonus if is_big else 0)
	var note_dmg: float = maxf(1.0, damage * note_damage_multiplier)
	if is_big:
		note_dmg *= 1.5
	for i in range(count):
		var note = note_scene.instantiate()
		var a: = deg_to_rad(_spiral_offset + i * (360.0 / count) + randf_range(-6.0, 6.0))
		note.direction = Vector2(cos(a), sin(a))
		note.damage = note_dmg
		note.speed = note_speed
		note.source = source
		scene_tree.current_scene.add_child(note)
		note.global_position = source.global_position
		var sprite = note.get_node_or_null("Sprite2D")
		if sprite != null and note_textures.size() > 0:
			sprite.texture = note_textures.pick_random()

func _big_beat_wave(source):
	var radius_world: = BASE_RADIUS * _zone_scale()
	var wave_dmg: float = maxf(1.0, damage * big_beat_wave_damage_multiplier)
	for enemy in source.get_tree().get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var dist = source.global_position.distance_to(enemy.global_position)
		if dist <= radius_world:
			if enemy.has_method("take_damage"):
				var final: = wave_dmg
				if "might" in source:
					final *= source.might
				enemy.take_damage(final)
			if "knockback" in enemy:
				var dir = (enemy.global_position - source.global_position).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.UP
				enemy.knockback = dir * big_beat_knockback

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "area" in upgrade:
		area_percent += upgrade.area * 100.0
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "damage" in upgrade:
		damage += upgrade.damage
	level += 1
	notes_amount = 5 + level
	note_speed = 240.0 + level * 10.0
	big_beat_knockback = 200.0 + level * 10.0
