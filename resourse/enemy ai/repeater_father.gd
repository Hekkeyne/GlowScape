class_name SplitterAI
extends EnemyAIBehavior

@export_range(50.0, 1500.0, 50.0) var accel_range: float = 400.0
@export_range(0.1, 3.0, 0.1) var ramp_time: float = 1.0
@export_range(1.0, 6.0, 0.5) var max_speed_mult: float = 2.0
@export var fast_anim: String = "fast"
@export var normal_anim: String = "run"
@export_range(1, 3) var min_children: int = 1
@export_range(1, 3) var max_children: int = 3
@export var child_type: Enemy
@export var explode_texture: Texture2D
@export_range(100.0, 1000.0, 50.0) var explode_knockback: float = 400.0

var speed_factor: float = 1.0
var exploded: bool = false

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var e = enemy as EnemyBase
	if not e or not is_instance_valid(player):
		return Vector2.ZERO
	var to_player = player.global_position - e.global_position
	var distance = to_player.length()
	var direction = to_player.normalized()
	if e.has_method("set_separation"):
		e.set_separation(distance)
	var in_zone = distance <= accel_range
	var target = max_speed_mult if in_zone else 1.0
	var rate = (max_speed_mult - 1.0) / ramp_time
	speed_factor = move_toward(speed_factor, target, rate * delta)
	e.play_anim(fast_anim if in_zone else normal_anim)
	e.run_particles_enabled = not in_zone
	if e.speed_up_particles:
		e.speed_up_particles.emitting = in_zone
	return direction * e.speed * speed_factor

func on_touch_player(e: EnemyBase, player: Node2D) -> void :
	if exploded or e.is_dying:
		return
	exploded = true
	if is_instance_valid(player) and player.has_method("apply_knockback"):
		var dir = (player.global_position - e.global_position).normalized()
		player.apply_knockback(dir * explode_knockback)
	e.explode_fx(explode_texture)
	e.screen_shake()
	e.run_particles_enabled = false
	if e.speed_up_particles:
		e.speed_up_particles.emitting = false
	_spawn_children(e)
	e.die()

func on_death(enemy: CharacterBody2D) -> void :
	if exploded:
		return
	var e = enemy as EnemyBase
	if not e or not child_type:
		return
	if e.get_tree().get_node_count_in_group("Enemy") > 120:
		return
	_spawn_children(e)

func _spawn_children(e: EnemyBase) -> void :
	var scene = child_type.scene
	if not scene:
		return
	for i in range(randi_range(min_children, max_children)):
		var child = scene.instantiate()
		child.type = child_type
		child.is_elite = false
		child.global_position = e.global_position
		child.player_ref = e.player_ref
		e.get_tree().current_scene.add_child.call_deferred(child)
