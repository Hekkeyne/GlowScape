extends Area2D
class_name BoomerangProjectile

@export var sfx: Array[AudioStream] = []
@export var return_sfx: Array[AudioStream] = []
var direction: = Vector2.RIGHT
var speed: = 300.0
var return_speed: = 340.0
var damage: = 1.0
var knockback: = 90.0
var source
var max_distance: = 260.0
var turn_rate: = 8.0
var return_ramp: = 0.7
var _state: = "OUT"
var _traveled: = 0.0
var _current_speed: = 0.0
var _return_time: = 0.0
var _turn_speed: = 0.0
var _hit_enemies: Array = []
var lifetime: = 6.0

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
	var has_source: = is_instance_valid(source)
	if _state == "OUT":
		var progress: = clampf(_traveled / max_distance, 0.0, 1.0)
		var slow_zone: = clampf((progress - 0.6) / 0.4, 0.0, 1.0)
		_current_speed = lerpf(speed, speed * 0.4, slow_zone * slow_zone)
		global_position += direction * _current_speed * delta
		_traveled += _current_speed * delta
		if _traveled >= max_distance * 0.85:
			_turn_back()
	else:
		if has_source:
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
	rotation_degrees += 900.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _turn_back() -> void :
	_state = "RETURN"
	_turn_speed = _current_speed
	_hit_enemies.clear()
	_play_sfx(return_sfx, global_position, -20.0)

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
