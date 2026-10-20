extends Area2D
class_name HomingStar

@export var homing_radius: float = 200.0
@export var homing_strength: float = 8.0
@export var max_pierce: int = 3
@export var knockback: float = 40.0
@export var lifetime: float = 3.0
@export var spin_speed: float = 6.0
@export var speed_start: float = 100.0
@export var speed_max: float = 500.0
@export var speed_accel: float = 300.0
@export var speed_drop_mult: float = 0.7

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 10.0
var source: Node2D = null
var player_ref: Node2D = null
var bullet_texture: Texture2D = null

var _hit_enemies: Array = []
var _age: float = 0.0
var _pierce_count: int = 0
var _current_speed: float = 100.0
var _current_max_speed: float = 500.0
var _home_target: Node2D = null
var _home_timer: float = 0.0

const HOMING_INTERVAL: float = 0.15

func _ready() -> void:
	_current_speed = speed_start
	_current_max_speed = speed_max
	add_to_group("Projectile")
	if bullet_texture:
		var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
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
	_process_homing(delta)
	_current_speed = minf(_current_speed + speed_accel * delta, _current_max_speed)
	rotation += spin_speed * delta
	global_position += direction * _current_speed * delta

func _process_homing(delta: float) -> void:
	_home_timer -= delta
	if _home_timer <= 0.0 or not is_instance_valid(_home_target) or _hit_enemies.has(_home_target):
		_home_timer = HOMING_INTERVAL
		_home_target = _find_home_target()
	if not is_instance_valid(_home_target):
		return
	var desired: float = (_home_target.global_position - global_position).angle()
	var diff: float = wrapf(desired - direction.angle(), -PI, PI)
	direction = direction.rotated(signf(diff) * minf(absf(diff), homing_strength * delta))

func _find_home_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var enemies: Array = get_tree().get_nodes_in_group("Enemy")
	for node in enemies:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _hit_enemies.has(enemy):
			continue
		var d: float = enemy.global_position.distance_to(global_position)
		if d > homing_radius:
			continue
		var to: Vector2 = (enemy.global_position - global_position).normalized()
		if to.dot(direction) < 0.25:
			continue
		if d < best_d:
			best_d = d
			best = enemy
	return best

func _on_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body == source:
		return
	if not body.is_in_group("Enemy"):
		return
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	var target: Node2D = area.get_parent() as Node2D
	if target == null or not is_instance_valid(target):
		return
	if target == source:
		return
	if not target.is_in_group("Enemy"):
		return
	_hit(target)

func _hit(target: Node) -> void:
	if _hit_enemies.has(target):
		return
	_hit_enemies.append(target)
	var final_damage: float = damage
	if source != null and "might" in source:
		final_damage *= float(source.might)
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		var kb: Vector2 = (target.global_position - global_position).normalized()
		if kb == Vector2.ZERO:
			kb = direction
		target.knockback = kb * knockback
	_pierce_count += 1
	_current_max_speed *= speed_drop_mult
	if _pierce_count >= max_pierce:
		queue_free()
