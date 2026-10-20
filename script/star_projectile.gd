extends Area2D
class_name StarProjectile

@export var sfx_hit: Array[AudioStream] = []
@export var spin_speed: float = 8.0
@export var lifetime: float = 3.0
@export var knockback: float = 40.0
@export var max_pierce: int = 3
@export var pierce_slowdown: float = 0.25

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 10.0
var source: Node2D = null
var bullet_texture: Texture2D = null
var weapon_ref: Weapon = null

var _hit_enemies: Array = []
var _age: float = 0.0
var _pierce_count: int = 0
var _current_speed: float = 300.0

func _ready() -> void:
	_current_speed = speed
	add_to_group("Projectile")
	if bullet_texture:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = bullet_texture
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	rotation += spin_speed * delta
	global_position += direction * _current_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body == source:
		return
	if not body.is_in_group("Enemy"):
		return
	_hit(body, body.global_position)

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if target == source:
		return
	if not target.is_in_group("Enemy"):
		return
	_hit(target, target.global_position)

func _hit(target: Node, hit_position: Vector2) -> void:
	if _hit_enemies.has(target):
		return
	_hit_enemies.append(target)
	var final_damage = damage
	if source != null and "might" in source:
		final_damage *= source.might
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		var kb = (target.global_position - global_position).normalized()
		if kb == Vector2.ZERO:
			kb = direction
		target.knockback = kb * knockback
	_play_hit_sfx(hit_position)
	_play_pierce_flash()
	_pierce_count += 1
	_current_speed = max(50.0, _current_speed * (1.0 - pierce_slowdown))
	if _pierce_count >= max_pierce:
		queue_free()

func _play_pierce_flash() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
	var original = sprite.modulate
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.04)
	tw.tween_property(sprite, "modulate", original, 0.08)

func _play_hit_sfx(pos: Vector2) -> void:
	if sfx_hit.is_empty():
		return
	var player = AudioStreamPlayer2D.new()
	player.stream = sfx_hit.pick_random()
	player.volume_db = -12
	player.pitch_scale = randf_range(0.8, 1.25)
	player.global_position = pos
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
