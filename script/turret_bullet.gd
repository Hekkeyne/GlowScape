extends Area2D
class_name TurretBullet
@export var sfx: Array[AudioStream] = []
var direction: = Vector2.RIGHT
var speed: = 250
var damage: = 10
var source
var lifetime: = 1.5

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void :
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void :
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	_hit(body)

func _on_area_entered(area: Area2D) -> void :
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	_hit(target)

func _hit(target: Node) -> void :
	var final_damage = damage
	if source != null and "might" in source:
		final_damage *= source.might
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		var kb = (target.global_position - global_position).normalized()
		if kb == Vector2.ZERO:
			kb = Vector2.RIGHT
		target.knockback = kb * 40.0
	if not sfx.is_empty():
		_spawn_audio(sfx.pick_random(), global_position, -18.0)
	queue_free()

func _spawn_audio(stream: AudioStream, pos: Vector2, volume_db: = -12.0) -> void :
	if stream == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.8, 1.25)
	player.global_position = pos
	scene.add_child(player)
	player.play()
	player.finished.connect( func(): player.queue_free())
