extends Node2D
class_name TurretUnit
@export var sfx_shoot: Array[AudioStream] = []
@export var sfx_zap: Array[AudioStream] = []
@export var sfx_rocket: Array[AudioStream] = []
var orbit_angle: = 0
var orbit_speed: = 90.0
var orbit_radius: = 60.0
var turret_type: = "mg"
var damage: = 10.0
var source
var lifetime: = 10.0
var attack_range: = 420.0
var bullet_scene: PackedScene
var rocket_scene: PackedScene
var zap_texture: Texture2D
var explosion_texture: Texture2D
var _fire_timer: = 0.5
var _target: Node2D = null
var bullet_texture: Texture2D
var rocket_texture: Texture2D

func _physics_process(delta: float) -> void :
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if lifetime < 2.0:
		modulate.a = 0.2 + 0.2 * abs(sin(lifetime * 10.0))
	else:
		modulate.a = 1.0
	if is_instance_valid(source):
		orbit_angle += orbit_speed * delta
		var a = deg_to_rad(orbit_angle)
		global_position = source.global_position + orbit_radius * Vector2(cos(a), sin(a))
	else:
		queue_free()
		return
	_fire_timer -= delta
	_target = _find_nearest_enemy()
	_target = _find_nearest_enemy()
	if is_instance_valid(_target) and _fire_timer <= 0.0:
		_fire()

func _is_valid_target(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy is Node2D:
		return false
	if "health" in enemy and "speed" in enemy:
		if enemy.health <= 0.0 and enemy.speed <= 0.0:
			return false
	if "health" in enemy and enemy.health <= 0.0:
		return false
	return true
func _fire() -> void :
	match turret_type:
		"mg":
			_fire_mg()
		"lightning":
			_fire_lightning()
		"rocket":
			_fire_rocket()

func _fire_mg() -> void :
	if bullet_scene == null or not is_instance_valid(_target):
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var dir = (_target.global_position - global_position).normalized()
	var bullet = bullet_scene.instantiate()
	var bullet_sprite = bullet.find_child("Sprite2D")
	if bullet_sprite != null and bullet_texture != null:
		bullet_sprite.texture = bullet_texture
	bullet.direction = dir
	bullet.speed = 520.0
	bullet.damage = max(1.0, damage * 0.5)
	bullet.source = source
	bullet.global_position = global_position + dir * 14.0
	scene.add_child(bullet)
	_fire_timer = 0.3
	_play_sfx(sfx_shoot, global_position, -18.0)

func _fire_lightning() -> void :
	if not is_instance_valid(_target):
		return
	var first_pos = _target.global_position
	var hit_list: = [_target]
	var current = _target
	_damage_enemy(current, damage * 0.8)
	for i in range(2):
		var next = _find_nearest_enemy_excluding(current.global_position, hit_list, 180.0)
		if next == null:
			break
		_spawn_zap(current.global_position, next.global_position)
		_damage_enemy(next, damage * 0.6)
		hit_list.append(next)
		current = next
	_spawn_zap(global_position + Vector2(0.0, -10.0), first_pos)
	_fire_timer = 0.9
	_play_sfx(sfx_zap, global_position, -14.0)

func _fire_rocket() -> void :
	if rocket_scene == null or not is_instance_valid(_target):
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var dir = (_target.global_position - global_position).normalized()
	var rocket = rocket_scene.instantiate()
	var rocket_sprite = rocket.find_child("Sprite2D")
	if rocket_sprite != null and rocket_texture != null:
		rocket_sprite.texture = rocket_texture
	rocket.target_node = _target
	rocket.damage = max(1.0, damage * 1.2)
	rocket.source = source
	rocket.direction = dir
	rocket.speed = 260.0
	rocket.explosion_texture = explosion_texture
	rocket.global_position = global_position + dir * 14.0
	scene.add_child(rocket)
	_fire_timer = 1.6
	_play_sfx(sfx_rocket, global_position, -16.0)

func _damage_enemy(enemy: Node, base_damage: float) -> void :
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("take_damage"):
		return
	var final_damage = base_damage
	if source != null and "might" in source:
		final_damage *= source.might
	enemy.take_damage(final_damage)

func _find_nearest_enemy() -> Node2D:
	return _find_nearest_enemy_excluding(global_position, [], attack_range)

func _find_nearest_enemy_excluding(from_pos: Vector2, exclude: Array, radius: float) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var best: Node2D = null
	var best_distance = radius
	for enemy in enemies:
		if not _is_valid_target(enemy):
			continue
		if exclude.has(enemy):
			continue
		var dist = from_pos.distance_to(enemy.global_position)
		if dist <= best_distance:
			best_distance = dist
			best = enemy
	return best


func _spawn_zap(from_pos: Vector2, to_pos: Vector2) -> void :
	if zap_texture == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var sprite = Sprite2D.new()
	sprite.texture = zap_texture
	sprite.z_index = 20
	sprite.centered = true
	sprite.global_position = from_pos.lerp(to_pos, 0.5)
	sprite.rotation = (to_pos - from_pos).angle()
	sprite.flip_v = randf() > 0.5
	var dist = from_pos.distance_to(to_pos)
	var base_width = max(1.0, float(zap_texture.get_width()))
	sprite.scale.x = max(0.15, dist / base_width)
	scene.add_child(sprite)
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(sprite.queue_free)

func _play_sfx(streams: Array[AudioStream], pos: Vector2, volume: float):
	if streams.is_empty():
		return
	_spawn_audio(streams.pick_random(), pos, volume)
func _spawn_audio(stream: AudioStream, pos: Vector2, volume_db: = -12.0) -> void :
	if stream == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.8, 1.25)
	player.global_position = pos
	scene.add_child(player)
	player.play()
	player.finished.connect( func(): player.queue_free())
