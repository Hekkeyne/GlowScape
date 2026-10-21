extends Area2D
class_name TurretRocket
@export var sfx: Array[AudioStream] = []
var direction: = Vector2.RIGHT
var speed: = 500

var damage: = 12.0
var source
var target_node: Node2D = null
var explosion_radius: = 80.0
var turn_speed: = 6.0
var explosion_texture: Texture2D
var lifetime: = 3.0
var _exploded: = false

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void :
	lifetime -= delta
	if lifetime <= 0.0:
		_explode(global_position)
		queue_free()
		return
	if is_instance_valid(target_node):
		var desired = (target_node.global_position - global_position).normalized()
		var new_dir = direction.lerp(desired, min(1.0, turn_speed * delta))
		if new_dir.length_squared() > 0.0001:
			direction = new_dir.normalized()
		if global_position.distance_to(target_node.global_position) < 14.0:
			_explode(target_node.global_position)
			queue_free()
			return
	global_position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void :
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	_explode(body.global_position)
	queue_free()

func _on_area_entered(area: Area2D) -> void :
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	var pos = global_position
	if target is Node2D:
		pos = target.global_position
	_explode(pos)
	queue_free()

func _explode(pos: Vector2) -> void :
	if _exploded:
		return
	_exploded = true
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist <= explosion_radius:
			var final_damage = damage * (1.0 - (dist / explosion_radius) * 0.5)
			if source != null and "might" in source:
				final_damage *= source.might
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage)
			if "knockback" in enemy:
				var kb = (enemy.global_position - pos).normalized()
				if kb == Vector2.ZERO:
					kb = Vector2.UP
				enemy.knockback = kb * 120.0
	_spawn_explosion(pos)
	if not sfx.is_empty():
		_spawn_audio(sfx.pick_random(), pos, -10.0)

func _spawn_explosion(pos: Vector2) -> void :
	if explosion_texture == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var sprite = Sprite2D.new()
	sprite.texture = explosion_texture
	sprite.z_index = 19
	sprite.global_position = pos
	sprite.scale = Vector2(0.5, 0.5)
	scene.add_child(sprite)
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(sprite.queue_free)

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
