class_name LungeAI
extends EnemyAIBehavior

@export_range(50.0, 2000.0, 50.0) var chase_range: float = 1100.0
@export_range(20.0, 400.0, 10.0) var prepare_range: float = 150.0
@export_range(0.1, 3.0, 0.1) var prepare_time: float = 1.0
@export_range(1.0, 10.0, 0.5) var dash_speed_mult: float = 4.0
@export_range(20.0, 400.0, 10.0) var keep_distance: float = 100.0
@export_range(0.0, 2.0, 0.05) var back_speed_mult: float = 0.8
@export_range(0.0, 2.0, 0.05) var creep_speed_mult: float = 0.3

enum State{CHASE, PREPARE, DASH}
var state: int = State.CHASE
var timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_remaining: float = 0.0
var trail_timer: float = 0.0
var aura: Sprite2D = null

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	if not player or not is_instance_valid(player):
		return Vector2.ZERO
	var to_player = player.global_position - enemy.global_position
	var distance = to_player.length()
	var direction = to_player.normalized()
	if enemy.has_method("set_separation"):
		enemy.set_separation(distance)
	if distance > chase_range and not enemy.is_elite:
		enemy.queue_free()
		return Vector2.ZERO
	match state:
		State.CHASE:
			enemy.play_anim("undash")
			_set_prepare_visuals(enemy, false)
			if enemy.modulate != Color.WHITE:
				enemy.modulate = enemy.modulate.lerp(Color.WHITE, 10.0 * delta)
				if enemy.modulate.is_equal_approx(Color.WHITE):
					enemy.modulate = Color.WHITE
			if enemy.dash_particles:
				enemy.dash_particles.emitting = false
			if distance <= prepare_range:
				state = State.PREPARE
				timer = 0.0
				return Vector2.ZERO
			return direction * enemy.speed
		State.PREPARE:
			enemy.play_anim("prepare")
			timer += delta
			_set_prepare_visuals(enemy, true)
			var charge = clampf(timer / prepare_time, 0.0, 2.0)
			enemy.modulate = Color(1.0 + charge, 1.0 + charge, 1.0 + charge)
			if distance > prepare_range * 2:
				enemy.visual_node.stop()
				enemy.visual_node.speed_scale = -1
				enemy.visual_node.play()
				state = State.CHASE
				_set_prepare_visuals(enemy, false)
				return direction * enemy.speed
			if timer >= prepare_time:
				state = State.DASH
				dash_direction = direction
				dash_remaining = distance * 2.0
				_set_prepare_visuals(enemy, false)
				return dash_direction * enemy.speed * dash_speed_mult
			if distance < keep_distance * 0.7:
				return - direction * enemy.speed * back_speed_mult
			elif distance > keep_distance:
				return direction * enemy.speed * creep_speed_mult
			return Vector2.ZERO
		State.DASH:
			if enemy.dash_particles:
				enemy.dash_particles.emitting = true
			if enemy.modulate != Color.WHITE:
				enemy.modulate = enemy.modulate.lerp(Color.WHITE, 10.0 * delta)
				if enemy.modulate.is_equal_approx(Color.WHITE):
					enemy.modulate = Color.WHITE
			var step = enemy.speed * dash_speed_mult * delta
			dash_remaining -= step
			if dash_remaining <= 0.0:
				state = State.CHASE
			return dash_direction * enemy.speed * dash_speed_mult
	return Vector2.ZERO

func get_facing(enemy: CharacterBody2D, player: Node2D) -> Vector2:
	match state:
		State.PREPARE:
			if is_instance_valid(player):
				return (player.global_position - enemy.global_position).normalized()
		State.DASH:
			return dash_direction
	return Vector2.ZERO

func _set_prepare_visuals(enemy: EnemyBase, enabled: bool) -> void :
	var visual = enemy.visual_node
	if not visual:
		return
	if enabled:
		visual.position = Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	else:
		visual.position = Vector2.ZERO
