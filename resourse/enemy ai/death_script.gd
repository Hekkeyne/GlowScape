class_name ExecutionerAI
extends EnemyAIBehavior

@export_range(100.0, 1500.0, 25.0) var chase_speed: float = 340.0
@export_range(400.0, 4000.0, 100.0) var dash_speed: float = 1500.0
@export_range(0.15, 2.0, 0.05) var aim_time: float = 0.55
@export_range(0.05, 1.0, 0.05) var recover_time: float = 0.3
@export_range(0.0, 3.0, 0.1) var chase_time: float = 1.1
@export_range(0.0, 1.0, 0.05) var homing_part: float = 0.35
@export_range(0.0, 10.0, 0.5) var homing_strength: float = 2.5
@export_range(50.0, 800.0, 25.0) var dash_overshoot: float = 250.0
@export_range(1.0, 2.0, 0.05) var dash_stretch: float = 1.25
@export_range(1, 6) var swing_every: int = 3
@export var homing_slash_scene: PackedScene
@export_range(1, 6) var swing_count: int = 4
@export_range(5.0, 70.0, 5.0) var swing_angle: float = 35.0
@export_range(0.05, 0.6, 0.05) var swing_windup: float = 0.18
@export_range(0.05, 0.4, 0.05) var swing_strike: float = 0.12
@export_range(1, 4) var slashes_per_swing: int = 2
@export_range(0.0, 40.0, 2.0) var slash_spread: float = 12.0
@export_range(100.0, 1200.0, 50.0) var homing_speed: float = 420.0
@export_range(0.5, 8.0, 0.5) var homing_turn: float = 3.5
@export_range(0.0, 2.0, 0.05) var homing_delay: float = 0.35
@export_range(0.0, 1.0, 0.05) var teleport_chance: float = 0.25
@export_range(0.1, 2.0, 0.1) var tp_lead_time: float = 0.6
@export_range(300.0, 1500.0, 50.0) var tp_ahead_distance: float = 750.0
@export_range(200.0, 1000.0, 50.0) var tp_safe_distance: float = 550.0
@export_range(0.0, 2.0, 0.1) var tp_stagger_time: float = 0.5
@export_range(0.0, 10.0, 0.5) var teleport_cooldown: float = 4.0
@export var chase_anim: String = "run"
@export var aim_anim: String = "open"
@export var recover_anim: String = "close"
@export var swing_anim: String = "fast"

enum State{CHASE, AIM, DASH, RECOVER, SWING}
var state: int = State.CHASE
var state_timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var dash_length: float = 0.0
var dash_traveled: float = 0.0
var dashes_done: int = 0
var tp_cd: float = 0.0
var tp_roll_timer: float = 0.0
var swings_left: int = 0
var swing_side: float = 1.0
var swing_timer: float = 0.0
var strike_fired: bool = false

func on_spawn(enemy: CharacterBody2D, _player: Node2D) -> void :
	var e = enemy as EnemyBase
	if not e:
		return
	e.ignore_knockback = true
	e.no_smoothing = true
	e.force_particles = true

func on_touch_player(e: EnemyBase, player: Node2D) -> void :
	if not is_instance_valid(player):
		return
	if player.has_method("instant_death"):
		player.instant_death()
	elif player.has_method("take_damage"):
		player.take_damage(999999.0)

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var e = enemy as EnemyBase
	if not e or not is_instance_valid(player):
		return Vector2.ZERO
	var to_player = player.global_position - e.global_position
	var distance = to_player.length()
	var dir_to_player = to_player.normalized() if distance > 0.001 else Vector2.ZERO
	tp_cd -= delta
	state_timer += delta
	match state:
		State.CHASE:
			e.play_anim(chase_anim)
			e.modulate = Color.WHITE
			e.scale_mult = lerpf(e.scale_mult, 1.0, 10.0 * delta)
			if e.visual_node:
				e.visual_node.rotation = lerpf(e.visual_node.rotation, 0.0, 10.0 * delta)
				e.visual_node.offset = e.visual_node.offset.lerp(Vector2.ZERO, 20.0 * delta)
			tp_roll_timer += delta
			if tp_roll_timer >= 1.0:
				tp_roll_timer -= 1.0
				if tp_cd <= 0.0 and distance > 250.0 and randf() < teleport_chance:
					_blink(e, player)
					state_timer = - tp_stagger_time
					return Vector2.ZERO
			if state_timer >= chase_time:
				state_timer = 0.0
				if homing_slash_scene and dashes_done > 0 and dashes_done % swing_every == 0:
					state = State.SWING
					swings_left = swing_count
					swing_side = 1.0 if randf() < 0.5 else -1.0
					swing_timer = 0.0
					strike_fired = false
					e.play_anim(swing_anim)
				else:
					state = State.AIM
			return dir_to_player * chase_speed
		State.AIM:
			e.play_anim(aim_anim)
			var wp = clampf(state_timer / aim_time, 0.0, 1.0)
			if e.visual_node:
				var amp = lerpf(1.0, 7.0, wp * wp)
				e.visual_node.offset = Vector2(randf_range( - amp, amp), randf_range( - amp, amp))
			e.modulate = Color.WHITE.lerp(Color(1.0, 0.25, 0.2), wp)
			if wp >= 1.0:
				if e.visual_node:
					e.visual_node.offset = Vector2.ZERO
				e.scale_mult = dash_stretch
				_enter_dash(e, player)
			return dir_to_player * chase_speed * 0.15
		State.DASH:
			dash_traveled += dash_speed * delta
			if dash_traveled < dash_length * homing_part:
				dash_dir = dash_dir.lerp(dir_to_player, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			e.scale_mult = lerpf(e.scale_mult, 1.0, 6.0 * delta)
			if dash_traveled >= dash_length:
				dashes_done += 1
				e.scale_mult = 1.0
				e.modulate = Color.WHITE
				state = State.RECOVER
				state_timer = 0.0
			return dash_dir * dash_speed
		State.SWING:
			swing_timer += delta
			var phase_time = swing_windup + swing_strike
			if swing_timer < swing_windup:
				if e.visual_node:
					e.visual_node.rotation = lerpf(e.visual_node.rotation, - swing_side * 1.1, 25.0 * delta)
				e.scale_mult = lerpf(e.scale_mult, 1.12, 12.0 * delta)
				e.modulate = Color(1.0, 0.85, 0.6) if fmod(state_timer, 0.1) < 0.05 else Color.WHITE
			elif swing_timer < phase_time:
				if not strike_fired:
					strike_fired = true
					_fire_swing_slashes(e, player)
					e.screen_shake(8.0, 0.2)
				if e.visual_node:
					e.visual_node.rotation = lerpf(e.visual_node.rotation, swing_side * 1.3, 40.0 * delta)
				e.scale_mult = lerpf(e.scale_mult, 0.92, 25.0 * delta)
				e.modulate = Color.WHITE
			else:
				swings_left -= 1
				swing_side = - swing_side
				swing_timer = 0.0
				strike_fired = false
				if swings_left <= 0:
					e.modulate = Color.WHITE
					state = State.RECOVER
					state_timer = 0.0
			return dir_to_player * chase_speed * 0.1
		State.RECOVER:
			e.play_anim(recover_anim)
			e.scale_mult = lerpf(e.scale_mult, 1.0, 10.0 * delta)
			if e.visual_node:
				e.visual_node.rotation = lerpf(e.visual_node.rotation, 0.0, 12.0 * delta)
				e.visual_node.offset = e.visual_node.offset.lerp(Vector2.ZERO, 20.0 * delta)
			if state_timer >= recover_time:
				state = State.CHASE
				state_timer = 0.0
			return Vector2.ZERO
	return Vector2.ZERO

func _enter_dash(e: EnemyBase, player: Node2D) -> void :
	state = State.DASH
	state_timer = 0.0
	dash_traveled = 0.0
	var target = player.global_position
	dash_dir = (target - e.global_position).normalized()
	dash_length = e.global_position.distance_to(target) + dash_overshoot
	e.modulate = Color(1.0, 0.2, 0.2)

func _blink(e: EnemyBase, player: Node2D) -> void :
	var vel: = Vector2.ZERO
	if "velocity" in player and player.velocity is Vector2:
		vel = player.velocity
	var dir: Vector2
	if vel.length() > 50.0:
		dir = vel.normalized()
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var dist = maxf(minf(vel.length() * tp_lead_time, tp_ahead_distance), tp_safe_distance)
	e.teleport_to(player.global_position + dir * dist)
	tp_cd = teleport_cooldown

func _fire_swing_slashes(e: EnemyBase, player: Node2D) -> void :
	if not homing_slash_scene:
		return
	var base_dir = (player.global_position - e.global_position).normalized()
	base_dir = base_dir.rotated(swing_side * deg_to_rad(swing_angle))
	var count = maxi(slashes_per_swing, 1)
	for i in range(count):
		var offset = deg_to_rad(slash_spread) * (float(i) - (count - 1) / 2.0)
		var s = homing_slash_scene.instantiate()
		s.direction = base_dir.rotated(offset)
		s.speed = homing_speed
		s.turn_rate = homing_turn
		s.homing_delay = homing_delay
		s.damage = e.damage
		s.source = e
		s.target = player
		s.global_position = e.global_position
		e.get_tree().current_scene.add_child(s)

func get_facing(enemy: CharacterBody2D, player: Node2D) -> Vector2:
	if state == State.DASH:
		return dash_dir
	if not is_instance_valid(player):
		return Vector2.ZERO
	return (player.global_position - enemy.global_position).normalized()
