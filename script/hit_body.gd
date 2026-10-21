extends CharacterBody2D

@export var damage: float = 10.0
var knockback: Vector2 = Vector2.ZERO

func _ready() -> void :
	collision_layer = 2
	collision_mask = 0
	add_to_group("Enemy")
	_ensure_collision_shape()

func _ensure_collision_shape() -> void :
	for child in get_children():
		if child is CollisionShape2D:
			return
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)

func take_damage(amount: float, is_crit: bool = false) -> void :
	var parent = get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(amount, is_crit)

func on_touch_player(player: CharacterBody2D) -> void :
	if player.has_method("take_damage"):
		player.take_damage(damage)
