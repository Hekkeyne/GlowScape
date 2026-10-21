extends Area2D
class_name VortexProjectile

var base_speed: float = 400.0
@export var dot_interval: float = 0.5
@export var knockback_force: float = 200.0
@export var min_alpha: float = 0.1
@export var wave_amplitude: float = 10.0
@export var wave_frequency: float = 4.0
@export var orbit_radius_ratio: float = 0.6
@export var enemy_orbit_speed_mult: float = 1.3

var max_scale_multiplier: float = 3.0
var damage: float = 10.0
var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var source: Node2D = null
var max_enemies: int = 3
var lifetime: float = 3.0
var texture_override: Texture2D = null

var _absorbed_enemies: Array = []
var _dot_timer: float = 0.0
var _is_dissipating: bool = false
var _age: float = 0.0
var _current_speed: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _wave_time: float = 0.0
var _spin_direction: float = 1.0
var _spin_speed: float = 8.0
var _enemy_angles: Dictionary = {}
var _visual_angle: float = 0.0
var _initialized: bool = false
var _start_scale: Vector2 = Vector2.ONE
var _start_modulate: Color = Color.WHITE
var _collision_radius: float = 1.0

func _ready() -> void:
	add_to_group("Projectile")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_start_scale = scale
	_start_modulate = modulate
	_collision_radius = _get_shape_radius()
	if speed <= 0.0:
		speed = base_speed
	if lifetime <= 0.0:
		lifetime = 0.1
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if _start_scale.length_squared() <= 0.0:
		_start_scale = Vector2.ONE
	_current_speed = speed
	_spin_direction = 1.0 if randf() < 0.5 else -1.0
	if _spin_direction==1.0:
		var sprite = get_node_or_null("Sprite2D")
		sprite.flip_h=true
	_spin_speed = randf_range(6.0, 14.0)
	_setup_visual()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _get_shape_radius() -> float:
	var shape = get_node_or_null("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		return maxf((shape.shape as CircleShape2D).radius, 1.0)
	return 1.0

func init_position() -> void:
	_base_position = global_position
	_initialized = true

func _setup_visual() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	if texture_override != null:
		sprite.texture = texture_override

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	if _is_dissipating:
		_tick_dissipation(delta)
		return
	_age += delta
	var progress = clampf(_age / lifetime, 0.0, 1.0)
	_base_position += direction * _current_speed * delta
	_wave_time += delta
	var perpendicular = Vector2(-direction.y, direction.x)
	var wave_offset = perpendicular * sin(_wave_time * wave_frequency) * wave_amplitude
	global_position = _base_position + wave_offset
	if _check_screen_exit():
		_start_dissipation()
		return
	var next_modulate = _start_modulate
	next_modulate.a = _start_modulate.a * lerpf(1.0, min_alpha, progress)
	modulate = next_modulate
	scale = _start_scale * lerpf(1.0, max_scale_multiplier, progress)
	var speed_penalty = _absorbed_enemies.size() * 0.2
	_current_speed = speed * (1.0 - speed_penalty)
	_current_speed = maxf(_current_speed, speed * 0.2)
	_orbit_enemies(delta)
	_update_visual(delta)
	_dot_timer += delta
	if _dot_timer >= dot_interval:
		_dot_timer = 0.0
		_apply_dot_damage()
	if _age >= lifetime:
		_start_dissipation()

func _screen_world_rect() -> Rect2:
	var vp = get_viewport()
	if vp == null:
		return Rect2(global_position - Vector2(600.0, 600.0), Vector2(1200.0, 1200.0))
	var vis = vp.get_visible_rect()
	var xform = vp.get_canvas_transform().affine_inverse()
	var a = xform * Vector2.ZERO
	var b = xform * vis.size
	return Rect2(a, b - a).abs()

func _check_screen_exit() -> bool:
	var rect = _screen_world_rect()
	var pos = global_position
	if pos.x < rect.position.x or pos.x > rect.end.x:
		return true
	if pos.y < rect.position.y or pos.y > rect.end.y:
		return true
	return false

func _orbit_enemies(delta: float) -> void:
	_absorbed_enemies = _absorbed_enemies.filter(func(e): return is_instance_valid(e))
	var dead_keys: Array = []
	for key in _enemy_angles.keys():
		if not is_instance_valid(key):
			dead_keys.append(key)
	for key in dead_keys:
		_enemy_angles.erase(key)
	var current_radius = _collision_radius * scale.x
	for enemy in _absorbed_enemies:
		if not _enemy_angles.has(enemy):
			_enemy_angles[enemy] = randf() * TAU
		_enemy_angles[enemy] += _spin_direction * _spin_speed * enemy_orbit_speed_mult * delta
		var orbit_radius = current_radius * orbit_radius_ratio
		var target_pos = global_position + Vector2.from_angle(_enemy_angles[enemy]) * orbit_radius
		enemy.global_position = target_pos

func _update_visual(delta: float) -> void:
	_visual_angle += _spin_direction * _spin_speed * delta
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.rotation = _visual_angle

func _on_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	if body == source:
		return
	_absorb_enemy(body)

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	if target == source:
		return
	_absorb_enemy(target)

func _absorb_enemy(enemy: Node2D) -> void:
	if _is_dissipating:
		return
	if _absorbed_enemies.has(enemy):
		return
	if _absorbed_enemies.size() >= max_enemies:
		_push_enemy_away(enemy)
		_deal_damage(enemy, 0.5)
		_start_dissipation()
		return
	_absorbed_enemies.append(enemy)
	_enemy_angles[enemy] = randf() * TAU
	_deal_damage(enemy, 1.0)

func _push_enemy_away(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if not "knockback" in enemy:
		return
	var kb_dir = (enemy.global_position - global_position).normalized()
	if kb_dir == Vector2.ZERO:
		kb_dir = Vector2.RIGHT
	enemy.knockback = kb_dir * knockback_force

func _apply_dot_damage() -> void:
	for enemy in _absorbed_enemies:
		_deal_damage(enemy, 1.0)

func _deal_damage(enemy: Node2D, multiplier: float = 1.0) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("take_damage"):
		return
	var final_damage = damage * multiplier
	if source != null and "might" in source:
		final_damage *= source.might
	enemy.take_damage(final_damage)

func _start_dissipation() -> void:
	if _is_dissipating:
		return
	_is_dissipating = true
	for enemy in _absorbed_enemies:
		if is_instance_valid(enemy):
			_push_enemy_away(enemy)
			_deal_damage(enemy, 0.5)
	_absorbed_enemies.clear()
	_enemy_angles.clear()
	_dissipate_visual()

func _dissipate_visual() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", scale * 1.5, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _tick_dissipation(delta: float) -> void:
	_base_position += direction * _current_speed * 0.3 * delta
	global_position = _base_position
	_current_speed *= 0.9
