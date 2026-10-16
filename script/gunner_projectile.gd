extends Area2D

@export var damage: float = 10.0
@export var lifetime: float = 3.0
@export_range(0.0, 1.0, 0.05) var back_time: float = 0.15
@export_range(0.0, 300.0, 10.0) var back_speed: float = 120.0
@export_range(0.1, 2.0, 0.1) var aim_time: float = 0.4
@export_range(100.0, 1000.0, 50.0) var max_speed: float = 380.0
@export var spin: float = 10.0
@export_range(0.05, 0.5, 0.05) var death_duration: float = 0.2

enum State { BACK, AIM, FLY }
var state: int = State.BACK
var state_timer: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var target: Node2D = null
var curve: float = 0.0
var back_heading: float = 0.0
var is_dying: bool = false

func _ready() -> void:
	back_heading = (-direction).angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_dying:
		return
	
	state_timer += delta
	
	match state:
		State.BACK:
			back_heading += curve * delta
			velocity = Vector2.RIGHT.rotated(back_heading) * back_speed
			if is_instance_valid(target):
				direction = (target.global_position - global_position).normalized()
				rotation = direction.angle()
			if state_timer >= back_time:
				state = State.AIM
				state_timer = 0.0
		State.AIM:
			velocity = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
			if is_instance_valid(target):
				direction = (target.global_position - global_position).normalized()
				rotation = direction.angle()
			if state_timer >= aim_time:
				state = State.FLY
				state_timer = 0.0
		State.FLY:
			velocity = direction * max_speed
			rotation += spin * delta
	
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_die()

func _on_body_entered(body: Node2D) -> void:
	if is_dying:
		return
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_die()

func _die() -> void:
	if is_dying:
		return
	is_dying = true
	var cs = find_child("CollisionShape2D")
	if cs:
		cs.set_deferred("disabled", true)
	_play_death_animation()

func _play_death_animation() -> void:
	var my_sprite = find_child("Sprite2D")
	if my_sprite and my_sprite.texture:
		for i in range(3):
			var shard = Sprite2D.new()
			shard.texture = my_sprite.texture
			shard.global_position = global_position
			shard.rotation = rotation + randf_range(-0.5, 0.5)
			shard.scale = scale * 0.6
			shard.modulate = Color(1.5, 1.5, 2.0, 1.0)
			get_parent().add_child(shard)
			var dir = Vector2.RIGHT.rotated(randf() * TAU)
			var tw = shard.create_tween().set_parallel(true)
			tw.tween_property(shard, "position", shard.position + dir * randf_range(30.0, 60.0), death_duration)
			tw.tween_property(shard, "modulate:a", 0.0, death_duration)
			tw.tween_property(shard, "rotation", shard.rotation + randf_range(-PI, PI), death_duration)
			tw.set_parallel(false)
			tw.tween_callback(shard.queue_free)
	queue_free()
