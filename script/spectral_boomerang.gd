extends Area2D
class_name SpectralBoomerangProjectile

@export var sfx: Array[AudioStream] = []
@export var return_sfx: Array[AudioStream] = []
@export_range(200.0, 1200.0, 25.0) var impulse_speed_min: = 400.0
@export_range(200.0, 1200.0, 25.0) var impulse_speed_max: = 700.0
@export_range(0.05, 1.0, 0.05) var impulse_time: = 0.3
@export_range(50.0, 2000.0, 50.0) var impulse_decel: = 300.0

var direction: = Vector2.RIGHT
var speed: = 300.0
var return_speed: = 380.0
var damage: = 1.0
var knockback: = 90.0
var source
var max_distance: = 280.0
var turn_rate: = 8.0
var return_ramp: = 0.7
var homing: = 2.5
var homing_radius: = 400.0
var split_count: = 3
var child_damage_multiplier: = 0.7
var split_scene: PackedScene
var is_split: = false
var _state: = "OUT"
var _traveled: = 0.0
var _current_speed: = 0.0
var _return_time: = 0.0
var _turn_speed: = 0.0
var _hit_enemies: Array = []
var lifetime: = 6.0
var current_target: Node2D = null
var _retarget_timer: = 0.0

var _in_impulse: = false
var _impulse_dir: = Vector2.ZERO
var _impulse_speed: = 0.0
var _impulse_timer: = 0.0

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	_current_speed = speed
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void :
	rotation_degrees += 900.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = 0.15
		current_target = _find_nearest_enemy()
	if is_split and _in_impulse:
		_impulse_timer -= delta
		_impulse_speed = maxf(_impulse_speed - impulse_decel * delta, 0.0)
		if is_instance_valid(current_target):
			var to_target: Vector2 = current_target.global_position - global_position
			var diff: = wrapf(to_target.angle() - _impulse_dir.angle(), - PI, PI)
			_impulse_dir = _impulse_dir.rotated(clampf(diff, - homing * delta, homing * delta))
		global_position += _impulse_dir * _impulse_speed * delta
		if _impulse_timer <= 0.0 or _impulse_speed <= 0.0:
			_in_impulse = false
			_state = "RETURN"
			_turn_speed = _impulse_speed
			_return_time = 0.0
			_hit_enemies.clear()
		return
	if _state == "OUT":
		var progress: = clampf(_traveled / max_distance, 0.0, 1.0)
		var slow_zone: = clampf((progress - 0.6) / 0.4, 0.0, 1.0)
		_current_speed = lerpf(speed, speed * 0.4, slow_zone * slow_zone)
		if is_instance_valid(current_target):
			var to_target: Vector2 = current_target.global_position - global_position
			var diff: = wrapf(to_target.angle() - direction.angle(), - PI, PI)
			direction = direction.rotated(clampf(diff, - homing * delta, homing * delta))
		global_position += direction * _current_speed * delta
		_traveled += _current_speed * delta
		if _traveled >= max_distance * 0.85:
			_turn_back()
	elif _state == "RETURN":
		if is_instance_valid(source):
			var to_source: Vector2 = source.global_position - global_position
			var dist: = to_source.length()
			if dist < 24.0:
				_play_sfx(return_sfx, global_position, -18.0)
				queue_free()
				return
			var diff: = wrapf(to_source.angle() - direction.angle(), - PI, PI)
			var turn_speed: = turn_rate
			if dist > max_distance * 1.1:
				turn_speed = turn_rate * 4.0
			direction = direction.rotated(clampf(diff, - turn_speed * delta, turn_speed * delta))
		_return_time += delta
		var t: = clampf(_return_time / return_ramp, 0.0, 1.0)
		_current_speed = lerpf(_turn_speed, return_speed, t * t)
		global_position += direction * _current_speed * delta

func _turn_back() -> void :
	if not is_split and split_count > 0 and split_scene != null:
		_spawn_splits()
		queue_free()
		return
	_state = "RETURN"
	_turn_speed = _current_speed
	_return_time = 0.0
	_hit_enemies.clear()
	_play_sfx(return_sfx, global_position, -20.0)

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance: = homing_radius
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var dist: = global_position.distance_to(enemy.global_position)
		if dist <= best_distance:
			best_distance = dist
			best = enemy
	return best

func _spawn_splits() -> void :
	var scene = get_tree().current_scene
	if scene == null:
		return
	var my_sprite = find_child("Sprite2D")
	var my_texture: Texture2D = null
	if my_sprite != null:
		my_texture = my_sprite.texture
	for i in range(int(split_count)):
		var child = split_scene.instantiate()
		child.is_split = true
		child.split_count = 0
		child.damage = max(1.0, damage * child_damage_multiplier)
		child.speed = speed
		child.return_speed = return_speed
		child.source = source
		child.lifetime = max(lifetime, 8.0)
		child.scale = Vector2(0.75, 0.75)
		child.modulate = Color(0.7, 0.9, 1.2, 0.9)
		child.global_position = global_position
		child._in_impulse = true
		child._impulse_dir = Vector2.RIGHT.rotated(randf() * TAU)
		child._impulse_speed = randf_range(impulse_speed_min, impulse_speed_max)
		child._impulse_timer = randf_range(impulse_time * 0.6, impulse_time * 1.6)
		child.direction = child._impulse_dir
		child.max_distance = max_distance
		child.turn_rate = turn_rate
		child.return_ramp = return_ramp
		child.homing = homing
		child.homing_radius = homing_radius
		var sprite = child.find_child("Sprite2D")
		if sprite != null and my_texture != null:
			sprite.texture = my_texture
		scene.add_child(child)

func _on_body_entered(body: Node2D) -> void :
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	_hit(body, body.global_position)

func _on_area_entered(area: Area2D) -> void :
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	var hit_position = area.global_position
	if target is Node2D:
		hit_position = target.global_position
	_hit(target, hit_position)

func _hit(target: Node, hit_position: Vector2) -> void :
	if _hit_enemies.has(target):
		return
	_hit_enemies.append(target)
	var final_damage = damage
	if source != null and "might" in source:
		final_damage *= source.might
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		var kb = (target.global_position - global_position).normalized()
		if kb == Vector2.ZERO:
			kb = Vector2.RIGHT
		target.knockback = kb * knockback
	_play_sfx(sfx, hit_position, -14.0)

func _play_sfx(streams: Array[AudioStream], pos: Vector2, volume: float):
	if streams.is_empty():
		return
	var player = get_node_or_null("AudioStreamPlayer2D")
	if player != null:
		player.stream = streams.pick_random()
		player.pitch_scale = randf_range(0.8, 1.2)
		player.play()
	else:
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
