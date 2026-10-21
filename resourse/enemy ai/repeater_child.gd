class_name ChildAI
extends EnemyAIBehavior

@export_range(0.5, 10.0, 0.5) var grow_time: float = 3.0
@export_range(0.1, 3.0, 0.1) var start_scale: float = 0.5
@export_range(0.5, 5.0, 0.1) var end_scale: float = 2.0
@export_range(0.0, 5.0, 0.25) var invincible_time: float = 1.0
@export_range(10.0, 300.0, 10.0) var scatter_force: float = 120.0
@export_file("*.tres") var adult_path: String = ""

var timer: float = 0.0
var grown: bool = false

func on_spawn(enemy: CharacterBody2D, player: Node2D) -> void :
	var e = enemy as EnemyBase
	if not e:
		return
	var dir = Vector2.RIGHT.rotated(randf() * TAU)
	e.knockback = dir * randf_range(scatter_force * 0.4, scatter_force)
	e.rotation = randf() * TAU
	e.scale = Vector2(start_scale, start_scale) * (2.0 if e.is_elite else 1.0)
	if e.is_elite:
		_disable_collision(e)
	e.set_invincible(invincible_time)

func _disable_collision(e: EnemyBase) -> void :
	if e.collision_shape:
		e.collision_shape.set_deferred("disabled", true)

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var e = enemy as EnemyBase
	if not e or grown:
		return Vector2.ZERO
	timer += delta
	if is_instance_valid(player):
		e.set_separation(e.global_position.distance_to(player.global_position))
	var progress = clampf(timer / grow_time, 0.0, 1.0)
	var elite_mult = 2.0 if e.is_elite else 1.0
	var s = lerpf(start_scale, end_scale, progress) * elite_mult
	e.scale = Vector2(s, s)
	if progress >= 1.0:
		grown = true
		_grow(e)
	return Vector2.ZERO

func _grow(e: EnemyBase) -> void :
	if adult_path.is_empty():
		push_error("ChildAI: не задан adult_path!")
		return
	var adult_type = load(adult_path) as Enemy
	if not adult_type or not adult_type.scene:
		push_error("ChildAI: не удалось загрузить взрослого из " + adult_path)
		return
	var was_elite = e.is_elite
	var adult = adult_type.scene.instantiate()
	adult.type = adult_type
	adult.is_elite = was_elite
	adult.global_position = e.global_position
	adult.player_ref = e.player_ref
	e.get_tree().current_scene.add_child.call_deferred(adult)
	e.remove_from_group("Enemy")
	e.queue_free()
