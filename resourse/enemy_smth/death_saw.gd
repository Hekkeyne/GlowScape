class_name ReaperHomingSlash
extends Area2D

var direction: = Vector2.RIGHT
var speed: = 420.0
var turn_rate: = 3.5
var homing_delay: = 0.35
var damage: = 10.0
var source: Node2D = null
var target: Node2D = null
var lifetime: = 3.5
var spin_speed: = 720.0
var _hit: = false

func _ready() -> void :
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void :
	if homing_delay > 0.0:
		homing_delay -= delta
	elif is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized()
		var diff = wrapf(desired.angle() - direction.angle(), - PI, PI)
		direction = direction.rotated(clampf(diff, - turn_rate * delta, turn_rate * delta))
	global_position += direction * speed * delta
	rotation_degrees += spin_speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void :
	if _hit or body == source:
		return
	if not body.is_in_group("player") and not body.has_method("take_damage"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction * 120.0)
	queue_free()
