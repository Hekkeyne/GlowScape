extends Area2D
@export var speed: float = 250.0
@export_range(0.1, 1.0, 0.1) var telegraph_time: float = 0.4
var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 1.0
var caster: Node2D = null
var decel: float = 0.0

func _ready() -> void :
	monitoring = false
	velocity = direction * speed
	decel = speed / maxf(lifetime, 0.05)

func _physics_process(delta: float) -> void :
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)
	position += velocity * delta
	rotation += 8.0 * delta * (velocity.length() / speed)
	lifetime -= delta
	if lifetime <= telegraph_time:
		modulate.a = 1.0 if fmod(lifetime, 0.12) > 0.06 else 0.3
		scale = scale.lerp(Vector2(1.6, 1.6), 10.0 * delta)
	if lifetime <= 0.0:
		if is_instance_valid(caster) and caster.has_method("teleport_to"):
			caster.teleport_to(global_position)
		queue_free()
