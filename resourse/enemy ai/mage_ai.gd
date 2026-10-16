class_name MageAI
extends EnemyAIBehavior

@export_range(100.0, 600.0, 25.0) var keep_range: float = 300.0
@export_range(2.0, 10.0, 0.5) var fire_interval: float = 3.0
@export_range(1, 3) var burst_count_min: int = 1
@export_range(1, 3) var burst_count_max: int = 3
@export_range(0.1, 0.5, 0.05) var shot_delay: float = 0.2
@export_range(0.5, 2.0, 0.1) var open_time: float = 1.0
@export_range(0.5, 2.0, 0.1) var close_time: float = 1.0
@export var projectile_scene: PackedScene

enum State { NORMAL, OPENING, SHOOTING, CLOSING }
var state: int = State.NORMAL
var fire_timer: float = 0.0
var burst_left: int = 0
var shot_timer: float = 0.0
var state_timer: float = 0.0

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var e = enemy as EnemyBase
	if not e or not is_instance_valid(player):
		return Vector2.ZERO
	var to_player = player.global_position - e.global_position
	var distance = to_player.length()
	var direction = to_player.normalized()
	if e.has_method("set_separation"):
		e.set_separation(distance)
	match state:
		State.NORMAL:
			fire_timer += delta
			if fire_timer >= fire_interval:
				fire_timer = 0.0
				state = State.OPENING
				state_timer = 0.0
				e.play_anim("open")
			return _move_to_range(e, player, distance, direction)
		State.OPENING:
			state_timer += delta
			if state_timer >= open_time:
				state = State.SHOOTING
				burst_left = randi_range(burst_count_min, burst_count_max)
				shot_timer = 0.0
				_shoot(e, player)
				burst_left -= 1
			return Vector2.ZERO
		State.SHOOTING:
			if burst_left > 0:
				shot_timer += delta
				if shot_timer >= shot_delay:
					shot_timer = 0.0
					burst_left -= 1
					_shoot(e, player)
			else:
				state = State.CLOSING
				state_timer = 0.0
				e.play_anim("close")
			return Vector2.ZERO
		State.CLOSING:
			state_timer += delta
			if state_timer >= close_time:
				state = State.NORMAL
			return _move_to_range(e, player, distance, direction)
	return Vector2.ZERO

func _move_to_range(e: EnemyBase, player: Node2D, distance: float, direction: Vector2) -> Vector2:
	var radial = clampf((distance - keep_range) / 100.0, -1.0, 1.0)
	if absf(radial) > 0.1:
		return direction * radial * e.speed
	return Vector2.ZERO

func _shoot(e: EnemyBase, player: Node2D) -> void:
	if not projectile_scene:
		return
	var to_player = (player.global_position - e.global_position).normalized()
	var perp = Vector2(-to_player.y, to_player.x)
	_squash_toward(e, perp)
	for side in [-1.0, 1.0]:
		var p = projectile_scene.instantiate()
		p.direction = perp * side
		p.target = player
		p.damage = e.damage
		p.global_position = e.global_position
		e.get_tree().current_scene.add_child(p)

func _squash_toward(e: EnemyBase, dir: Vector2) -> void:
	if not e.visual_node:
		return
	var local_dir = dir.rotated(-e.rotation)
	var squash = Vector2(1.0, 1.0)
	if absf(local_dir.x) > absf(local_dir.y):
		squash = Vector2(0.7, 1.3)
	else:
		squash = Vector2(1.3, 0.7)
	e.visual_node.scale = squash
	var tw = e.create_tween()
	tw.tween_property(e.visual_node, "scale", Vector2.ONE, 0.15)

func get_facing(enemy: CharacterBody2D, player: Node2D) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	return (player.global_position - enemy.global_position).normalized()
