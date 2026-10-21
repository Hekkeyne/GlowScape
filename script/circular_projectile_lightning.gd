extends Area2D
class_name OrbitalStormProjectile

@export var sfx: Array[AudioStream] = []
@export var chain_sfx: Array[AudioStream] = []
var direction: = Vector2.RIGHT
var speed: = 0.0
var damage: = 1.0
var source
var chain_damage: = 1.0
var chain_jumps: = 3
var chain_radius: = 150.0
var chain_cooldown: = 0.35
var chain_texture: Texture2D
var _last_chain_time: = 0

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if speed > 0.0:
		rotation = direction.angle()

func _physics_process(delta: float) -> void :
	if speed > 0.0:
		global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void :
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	var hit_position = body.global_position
	_damage_target(body, damage, 80.0)
	_play_hit_sfx(hit_position)
	_try_chain(body, hit_position)

func _on_area_entered(area: Area2D) -> void :
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		target = area
	if not target.is_in_group("Enemy"):
		return
	var hit_position = area.global_position
	if target is Node2D:
		hit_position = target.global_position
	_damage_target(target, damage, 80.0)
	_play_hit_sfx(hit_position)
	_try_chain(target, hit_position)

func _try_chain(initial_target: Node, start_position: Vector2) -> void :
	var now = Time.get_ticks_msec()
	if now - _last_chain_time < int(chain_cooldown * 1000.0):
		return
	_last_chain_time = now
	var hit_targets: Array = []
	if initial_target != null and is_instance_valid(initial_target):
		hit_targets.append(initial_target)
	var current_position = start_position
	for i in range(chain_jumps):
		var next_enemy = _find_next_enemy(current_position, hit_targets)
		if next_enemy == null:
			break
		var next_position = next_enemy.global_position
		_damage_target(next_enemy, chain_damage, 45.0)
		_spawn_chain_visual(current_position, next_position)
		hit_targets.append(next_enemy)
		current_position = next_position
	if hit_targets.size() > 0:
		_play_chain_sfx(current_position)

func _find_next_enemy(from_position: Vector2, exclude: Array) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var best: Node2D = null
	var best_distance = chain_radius
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		if exclude.has(enemy):
			continue
		var enemy_position = enemy.global_position
		var dist = from_position.distance_to(enemy_position)
		if dist <= best_distance:
			best_distance = dist
			best = enemy
	return best


func _damage_target(target: Node, base_damage: float, knockback_strength: float) -> void :
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return
	var final_damage = base_damage
	if source != null and "might" in source:
		final_damage *= source.might
	var knockback_direction = Vector2.RIGHT
	if target is Node2D:
		knockback_direction = (target.global_position - global_position).normalized()
		if knockback_direction == Vector2.ZERO:
			knockback_direction = Vector2.RIGHT
	target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		target.knockback = knockback_direction * knockback_strength


func _spawn_chain_visual(from_position: Vector2, to_position: Vector2) -> void :
	if chain_texture == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var sprite = Sprite2D.new()
	sprite.texture = chain_texture
	sprite.z_index = 20
	sprite.centered = true
	sprite.global_position = from_position.lerp(to_position, 0.5)
	sprite.rotation = (to_position - from_position).angle()
	sprite.modulate = Color(1.2, 1.25, 1.0, 0.95)
	sprite.flip_v = randf() > 0.5
	var dist = from_position.distance_to(to_position)
	var base_width = max(1.0, float(chain_texture.get_width()))
	sprite.scale.x = max(0.15, dist / base_width)
	scene.add_child(sprite)
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(sprite.queue_free)

func _play_hit_sfx(pos: Vector2) -> void :
	if sfx.is_empty():
		return
	var player = get_node_or_null("AudioStreamPlayer2D")
	if player != null:
		player.stream = sfx.pick_random()
		player.pitch_scale = randf_range(0.7, 1.3)
		player.play()
	else:
		_spawn_audio(sfx.pick_random(), pos, -16.0)

func _play_chain_sfx(pos: Vector2) -> void :
	if chain_sfx.is_empty():
		if sfx.is_empty():
			return
		_spawn_audio(sfx.pick_random(), pos, -14.0)
	else:
		_spawn_audio(chain_sfx.pick_random(), pos, -12.0)

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
