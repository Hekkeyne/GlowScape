extends Area2D
@export var sfx: Array[AudioStream] = []
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300
var damage: float = 1
var knockback: float = 90
var source
func _on_body_entered(body: Node2D) -> void :
	if body.has_method("take_damage"):
		if "might" in source:
			body.take_damage(damage * source.might)
		else:
			body.take_damage(damage)
		$AudioStreamPlayer2D.stream = sfx.pick_random()
		$AudioStreamPlayer2D.pitch_scale = randf_range(0.7, 1.3)
		$AudioStreamPlayer2D.play()
		body.knockback = direction * knockback

func _physics_process(delta: float) -> void :
	global_position += direction * speed * delta

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void :
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
