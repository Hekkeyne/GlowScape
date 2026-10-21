extends Area2D

@export var speed: float = 250.0
@export var damage: float = 10.0
@export var knockback_force: float = 300.0
@export var lifetime: float = 6.0
@export_range(0.5, 5.0, 0.5) var turn_speed: float = 2.5
@export_range(0.0, 0.5, 0.05) var initial_straight_time: float = 0.2
@export_range(0.05, 0.5, 0.05) var death_duration: float = 0.18

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null
var elapsed: float = 0.0
var is_dying: bool = false

func _ready() -> void :
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void :
	if is_dying:
		return

	elapsed += delta

	if not is_instance_valid(target):
		_die()
		return

	if elapsed >= initial_straight_time:
		var to_target = (target.global_position - global_position).normalized()
		var current_angle = direction.angle()
		var target_angle = to_target.angle()
		var angle_diff = wrapf(target_angle - current_angle, - PI, PI)
		var max_turn = turn_speed * delta
		direction = Vector2.RIGHT.rotated(current_angle + clampf(angle_diff, - max_turn, max_turn))

	position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		_die()

func _on_body_entered(body: Node2D) -> void :
	if is_dying:
		return
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var dir = (body.global_position - global_position).normalized()
			body.apply_knockback(dir * knockback_force)
		_die()

func _die() -> void :
	if is_dying:
		return
	is_dying = true

	var cs = find_child("CollisionShape2D")
	if cs:
		cs.set_deferred("disabled", true)

	_play_death_animation()

func _play_death_animation() -> void :
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.5, 2.5), death_duration)
	tw.tween_property(self, "modulate:a", 0.0, death_duration)
	tw.tween_property(self, "rotation", rotation + TAU * 0.75, death_duration)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
