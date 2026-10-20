extends Area2D
class_name StarSwordBlade
enum State { IDLE, SPIN_UP, SPIN_EMIT, FLY_WALL, RETURN }
@export var spin_up_time: float = 0.45
@export var charge_spin_speed: float = 18.0
@export var disc_spin_speed: float = 28.0
@export var spin_emit_time: float = 1.0
@export var emerge_time: float = 0.3
@export var emerge_spin_decel: float = 60.0
@export var fly_speed: float = 900.0
@export var fly_max_speed: float = 1500.0
@export var fly_passive_decel: float = 140.0
@export var bounce_damp: float = 0.75
@export var fly_hit_speed_boost: float = 200.0
@export var return_speed_threshold: float = 500.0
@export var target_turn_speed: float = 2.5
@export var target_influence_radius: float = 400.0
@export var hit_radius: float = 65.0
@export var trail_interval: float = 0.035
@export var trail_lifetime: float = 0.16
@export var trail_alpha: float = 0.5
@export var cooldown_alpha: float = 0.45
@export var trail_pool_size: int = 14
@export var cooldown_blink_time: float = 0.7
@export var return_max_speed: float = 700.0
var state: int = State.IDLE
var damage: float = 10.0
var cooldown: float = 3.0
var knockback: float = 120.0
var attack_radius: float = 200.0
var attack_margin: float = 120.0
var max_screen_margin: float = 25.0
var shake_strength: float = 0.35
var player_ref: Node2D = null
var bullet_texture: Texture2D = null
var disc_texture: Texture2D = null
var spin_star_count: int = 8
var spin_star_scene: PackedScene = null
var spin_star_textures: Array[Texture2D] = []
var base_bounce_star_count: int = 4
var max_bounce_star_count: int = 12
var bounce_star_scene: PackedScene = null
var bounce_star_textures: Array[Texture2D] = []
var base_distance: float = 150.0
var area_multiplier: float = 0.55
var follow_stiffness: float = 80.0
var follow_damping: float = 12.0
var side_swing_speed: float = 8.0
var sprite_forward_offset: float = 0.0
var _sprite: Sprite2D = null
var _disc_sprite: Sprite2D = null
var _home_velocity: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.RIGHT
var _front_angle: float = 0.0
var _rig_time: float = 0.0
var _cooldown_timer: float = 0.0
var _charge_timer: float = 0.0
var _spin_emit_timer: float = 0.0
var _spin_stars_spawned: int = 0
var _emerge_timer: float = 0.0
var _trail_timer: float = 0.0
var _trail_cursor: int = 0
var _trail_pool: Array[Sprite2D] = []
var _trail_life: Array[float] = []
var _current_spin: float = 0.0
var _disc_visual_spin: float = 0.0
var _spin_dir: float = 1.0
var _fly_dir: Vector2 = Vector2.RIGHT
var _fly_speed: float = 0.0
var _target: Node2D = null
var _hit_enemies: Array = []
func _ready() -> void:
	add_to_group("Projectile")
	collision_layer = 0
	collision_mask = 4294967295
	monitoring = true
	monitorable = false
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_disc_sprite = get_node_or_null("Sprite2D2") as Sprite2D
	if bullet_texture and _sprite:
		_sprite.texture = bullet_texture
	if disc_texture and _disc_sprite:
		_disc_sprite.texture = disc_texture
	if _sprite:
		_sprite.modulate.a = 1.0
	if _disc_sprite:
		_disc_sprite.visible = false
		_disc_sprite.modulate.a = 0.0
		_disc_sprite.rotation = 0.0
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	_setup_trail_pool()
	_rig_time = randf() * 100.0
	_cooldown_timer = cooldown * randf()
	global_position = _get_home_position()
	rotation = _get_home_rotation()
func _setup_trail_pool() -> void:
	var tex: Texture2D = null
	if _disc_sprite != null and _disc_sprite.texture != null:
		tex = _disc_sprite.texture
	elif disc_texture != null:
		tex = disc_texture
	for i in range(maxi(trail_pool_size, 1)):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.top_level = true
		ghost.visible = false
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.0)
		ghost.texture = tex
		add_child(ghost)
		move_child(ghost, 0)
		_trail_pool.append(ghost)
		_trail_life.append(0.0)
func _physics_process(delta: float) -> void:
	_update_move_dir(delta)
	match state:
		State.IDLE:
			_tick_idle(delta)
		State.SPIN_UP:
			_tick_spin_up(delta)
		State.SPIN_EMIT:
			_tick_spin_emit(delta)
		State.FLY_WALL:
			_tick_fly_wall(delta)
		State.RETURN:
			_tick_return(delta)
	_update_trail(delta)
func _update_move_dir(delta: float) -> void:
	if is_instance_valid(player_ref) and player_ref is CharacterBody2D:
		var v: Vector2 = (player_ref as CharacterBody2D).velocity
		if v.length_squared() > 400.0:
			_last_move_dir = v.normalized()
	var target_angle: float = _last_move_dir.angle()
	var diff: float = wrapf(target_angle - _front_angle, -PI, PI)
	_front_angle += signf(diff) * minf(absf(diff), side_swing_speed * delta)
func _get_home_position() -> Vector2:
	if not is_instance_valid(player_ref):
		return global_position
	var distance: float = base_distance + float(player_ref.area) * area_multiplier
	var offset: Vector2 = Vector2(distance, 0.0).rotated(_front_angle)
	return player_ref.global_position + offset
func _get_home_rotation() -> float:
	return _front_angle + deg_to_rad(sprite_forward_offset)
func _tick_idle(delta: float) -> void:
	_rig_time += delta
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	var target_pos: Vector2 = _get_home_position()
	_home_velocity += (target_pos - global_position) * follow_stiffness * delta
	_home_velocity *= exp(-follow_damping * delta)
	global_position += _home_velocity * delta
	rotation = lerp_angle(rotation, _get_home_rotation(), 10.0 * delta)
	if _sprite:
		if _cooldown_timer > 0.0:
			if _cooldown_timer < cooldown_blink_time:
				_sprite.modulate.a = 1.0 if fmod(_cooldown_timer, 0.2) < 0.1 else cooldown_alpha
			else:
				_sprite.modulate.a = cooldown_alpha
		else:
			_sprite.modulate.a = 1.0
	if _cooldown_timer <= 0.0:
		_find_target()
func _find_target() -> void:
	if not is_instance_valid(player_ref):
		return
	var best: Node2D = null
	var best_d: float = INF
	var usable_rect: Rect2 = _screen_world_rect().grow(-attack_margin)
	if usable_rect.size.x <= 0.0 or usable_rect.size.y <= 0.0:
		usable_rect = _screen_world_rect()
	var enemies: Array = get_tree().get_nodes_in_group("Enemy")
	for node in enemies:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not usable_rect.has_point(enemy.global_position):
			continue
		var d: float = enemy.global_position.distance_to(player_ref.global_position)
		if d > attack_radius:
			continue
		if d < best_d:
			best_d = d
			best = enemy
	if best != null:
		_target = best
		_start_spin_up()
func _start_spin_up() -> void:
	state = State.SPIN_UP
	_charge_timer = maxf(spin_up_time, 0.05)
	_current_spin = 0.0
	_spin_dir = 1.0 if randf() > 0.5 else -1.0
	_hit_enemies.clear()
	if _sprite:
		_sprite.modulate.a = 1.0
	if _disc_sprite:
		_disc_sprite.visible = false
		_disc_sprite.modulate.a = 0.0
		_disc_sprite.rotation = 0.0
func _tick_spin_up(delta: float) -> void:
	_rig_time += delta
	_charge_timer -= delta
	var progress: float = 1.0 - clampf(_charge_timer / maxf(spin_up_time, 0.001), 0.0, 1.0)
	_current_spin = charge_spin_speed * progress * progress
	rotation += _current_spin * delta * _spin_dir
	var fade_start: float = 0.65
	var fade: float = clampf((progress - fade_start) / maxf(1.0 - fade_start, 0.001), 0.0, 1.0)
	if _sprite:
		_sprite.modulate.a = 1.0 - fade
	if _disc_sprite:
		_disc_sprite.visible = fade > 0.0
		_disc_sprite.modulate.a = fade
		_disc_sprite.rotation = 0.0
	if _charge_timer <= 0.0:
		state = State.SPIN_EMIT
		_spin_stars_spawned = 0
		_spin_emit_timer = spin_emit_time / float(maxi(spin_star_count, 1))
func _tick_spin_emit(delta: float) -> void:
	_rig_time += delta
	_current_spin = lerpf(_current_spin, disc_spin_speed, 8.0 * delta)
	rotation += _current_spin * delta * _spin_dir
	_check_nearby_hits(false)
	_constrain_to_screen(false)
	_spin_emit_timer -= delta
	if _spin_emit_timer <= 0.0 and _spin_stars_spawned < spin_star_count:
		_spawn_spin_star()
		_spin_stars_spawned += 1
		_spin_emit_timer = spin_emit_time / float(maxi(spin_star_count, 1))
	if _spin_stars_spawned >= spin_star_count:
		_start_fly_wall()
func _start_fly_wall() -> void:
	state = State.FLY_WALL
	_fly_speed = fly_speed
	_hit_enemies.clear()
	if is_instance_valid(_target):
		_fly_dir = (_target.global_position - global_position).normalized()
	elif is_instance_valid(player_ref):
		_fly_dir = (global_position - player_ref.global_position).normalized()
	else:
		_fly_dir = Vector2.RIGHT.rotated(_front_angle)
	if _fly_dir.length_squared() < 0.001:
		_fly_dir = Vector2.RIGHT
	if _disc_sprite:
		_disc_sprite.visible = true
		_disc_sprite.modulate.a = 1.0
		_disc_sprite.rotation = 0.0
	if _sprite:
		_sprite.modulate.a = 0.0
	_constrain_to_screen(false)
func _tick_fly_wall(delta: float) -> void:
	_rig_time += delta
	_update_target_direction(delta)
	_fly_speed = maxf(_fly_speed - fly_passive_decel * delta, 0.0)
	global_position += _fly_dir * _fly_speed * delta
	_current_spin = lerpf(_current_spin, disc_spin_speed, 8.0 * delta)
	rotation += _current_spin * delta * _spin_dir
	_check_nearby_hits(true)
	if _constrain_to_screen(true):
		_on_wall_hit()
	if _fly_speed < return_speed_threshold:
		_start_return()
func _update_target_direction(delta: float) -> void:
	var best: Node2D = null
	var best_d: float = INF
	var enemies: Array = get_tree().get_nodes_in_group("Enemy")
	for node in enemies:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d: float = enemy.global_position.distance_to(global_position)
		if d > target_influence_radius:
			continue
		if d < best_d:
			best_d = d
			best = enemy
	if best != null and best_d > 0.01:
		_target = best
		var to_target: Vector2 = (best.global_position - global_position).normalized()
		var angle_diff: float = wrapf(to_target.angle() - _fly_dir.angle(), -PI, PI)
		var turn_amount: float = signf(angle_diff) * minf(absf(angle_diff), target_turn_speed * delta)
		_fly_dir = _fly_dir.rotated(turn_amount)
func _on_wall_hit() -> void:
	_fly_speed *= bounce_damp
	_spawn_bounce_stars()
	_shake_camera()
	_hit_enemies.clear()
func _start_return() -> void:
	state = State.RETURN
	_emerge_timer = maxf(emerge_time, 0.001)
	_disc_visual_spin = _current_spin
	_cooldown_timer = cooldown
	_hit_enemies.clear()
	_target = null
func _tick_return(delta: float) -> void:
	_rig_time += delta
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	_emerge_timer -= delta
	var progress: float = 1.0 - clampf(_emerge_timer / maxf(emerge_time, 0.001), 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	_disc_visual_spin = maxf(_disc_visual_spin - emerge_spin_decel * delta, 0.0)
	rotation += _disc_visual_spin * delta * _spin_dir
	if _disc_sprite:
		_disc_sprite.modulate.a = 1.0 - eased
		if eased >= 0.98:
			_disc_sprite.visible = false
	if _sprite:
		_sprite.modulate.a = eased
	var target_pos: Vector2 = _get_home_position()
	_home_velocity += (target_pos - global_position) * follow_stiffness * 1.5 * delta
	_home_velocity *= exp(-follow_damping * delta)
	if _home_velocity.length() > return_max_speed:
		_home_velocity = _home_velocity.normalized() * return_max_speed
	global_position += _home_velocity * delta
	if _emerge_timer <= 0.0:
		state = State.IDLE
		_current_spin = 0.0
		_disc_visual_spin = 0.0
		if _sprite:
			_sprite.modulate.a = 1.0 if _cooldown_timer <= 0.0 else cooldown_alpha
		if _disc_sprite:
			_disc_sprite.visible = false
			_disc_sprite.modulate.a = 0.0
			_disc_sprite.rotation = 0.0
		if _cooldown_timer <= 0.0:
			_find_target()
func _update_trail(delta: float) -> void:
	for i in range(_trail_pool.size()):
		if _trail_life[i] <= 0.0:
			continue
		_trail_life[i] -= delta
		var ghost: Sprite2D = _trail_pool[i]
		if _trail_life[i] <= 0.0:
			ghost.visible = false
			ghost.modulate.a = 0.0
		else:
			ghost.modulate.a = trail_alpha * (_trail_life[i] / trail_lifetime)
	if trail_lifetime <= 0.0 or trail_interval <= 0.0:
		return
	if state != State.SPIN_UP and state != State.SPIN_EMIT and state != State.FLY_WALL and state != State.RETURN:
		return
	if _disc_sprite == null or not _disc_sprite.visible:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = trail_interval
	_spawn_trail()
func _spawn_trail() -> void:
	if _disc_sprite == null or _disc_sprite.texture == null or _trail_pool.is_empty():
		return
	_trail_cursor = (_trail_cursor + 1) % _trail_pool.size()
	var ghost: Sprite2D = _trail_pool[_trail_cursor]
	ghost.texture = _disc_sprite.texture
	ghost.scale = _disc_sprite.scale
	ghost.global_position = _disc_sprite.global_position
	ghost.global_rotation = _disc_sprite.global_rotation
	ghost.modulate = Color(1.0, 1.0, 1.0, trail_alpha)
	ghost.visible = true
	_trail_life[_trail_cursor] = trail_lifetime
func _shake_camera() -> void:
	if shake_strength <= 0.0:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var cam: Camera2D = vp.get_camera_2d()
	if cam == null or not is_instance_valid(cam):
		return
	if cam.has_method("add_screen_shake"):
		cam.call("add_screen_shake", shake_strength)
func _on_body_entered(body: Node2D) -> void:
	if state != State.FLY_WALL and state != State.SPIN_EMIT:
		return
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	_try_hit(body, state == State.FLY_WALL)
func _on_area_entered(area: Area2D) -> void:
	if state != State.FLY_WALL and state != State.SPIN_EMIT:
		return
	if area == null or not is_instance_valid(area):
		return
	var target: Node2D = area.get_parent() as Node2D
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	_try_hit(target, state == State.FLY_WALL)
func _check_nearby_hits(speed_boost: bool) -> void:
	var radius_sq: float = hit_radius * hit_radius
	var enemies: Array = get_tree().get_nodes_in_group("Enemy")
	for node in enemies:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_squared_to(enemy.global_position) <= radius_sq:
			_try_hit(enemy, speed_boost)
func _try_hit(target: Node, speed_boost: bool) -> bool:
	var enemy: Node2D = target as Node2D
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.is_in_group("Enemy"):
		return false
	if _hit_enemies.has(enemy):
		return false
	_hit_enemies.append(enemy)
	var final_damage: float = damage
	if player_ref != null and "might" in player_ref:
		final_damage *= float(player_ref.might)
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage)
	if "knockback" in enemy:
		var kb_dir: Vector2 = (enemy.global_position - global_position).normalized()
		if kb_dir.length_squared() < 0.001:
			kb_dir = _fly_dir
		enemy.knockback = kb_dir * knockback
	if speed_boost and state == State.FLY_WALL and _fly_speed < fly_max_speed:
		_fly_speed = minf(_fly_speed + fly_hit_speed_boost, fly_max_speed)
	return true
func _constrain_to_screen(bounce: bool) -> bool:
	var rect: Rect2 = _screen_world_rect()
	var min_x: float = rect.position.x + max_screen_margin
	var max_x: float = rect.end.x - max_screen_margin
	var min_y: float = rect.position.y + max_screen_margin
	var max_y: float = rect.end.y - max_screen_margin
	if max_x <= min_x:
		min_x = rect.position.x
		max_x = rect.end.x
	if max_y <= min_y:
		min_y = rect.position.y
		max_y = rect.end.y
	var hit: bool = false
	if global_position.x < min_x:
		hit = true
		if bounce:
			_fly_dir.x = absf(_fly_dir.x)
	elif global_position.x > max_x:
		hit = true
		if bounce:
			_fly_dir.x = -absf(_fly_dir.x)
	if global_position.y < min_y:
		hit = true
		if bounce:
			_fly_dir.y = absf(_fly_dir.y)
	elif global_position.y > max_y:
		hit = true
		if bounce:
			_fly_dir.y = -absf(_fly_dir.y)
	if hit:
		global_position.x = clampf(global_position.x, min_x, max_x)
		global_position.y = clampf(global_position.y, min_y, max_y)
		if bounce:
			if _fly_dir.length_squared() < 0.001:
				_fly_dir = Vector2.RIGHT
			_fly_dir = _fly_dir.normalized()
	return hit
func _spawn_spin_star() -> void:
	if spin_star_scene == null:
		return
	var star: Node2D = spin_star_scene.instantiate() as Node2D
	if star == null:
		return
	var dir: Vector2 = Vector2.RIGHT.rotated(rotation)
	star.global_position = global_position + dir * 30.0
	star.set("direction", dir)
	star.set("damage", damage)
	star.set("source", player_ref)
	star.set("player_ref", player_ref)
	if spin_star_textures.size() > 0:
		star.set("bullet_texture", spin_star_textures.pick_random())
	get_tree().current_scene.add_child(star)
func _spawn_bounce_stars() -> void:
	if bounce_star_scene == null:
		return
	var speed_ratio: float = clampf(_fly_speed / maxf(fly_max_speed, 1.0), 0.0, 1.0)
	var count: int = int(lerpf(float(base_bounce_star_count), float(max_bounce_star_count), speed_ratio))
	count = maxi(count, 1)
	for i in range(count):
		var star: Node2D = bounce_star_scene.instantiate() as Node2D
		if star == null:
			continue
		var angle: float = TAU * float(i) / float(count)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		star.global_position = global_position + dir * 20.0
		star.set("direction", dir)
		star.set("damage", damage)
		star.set("source", player_ref)
		star.set("player_ref", player_ref)
		if bounce_star_textures.size() > 0:
			star.set("bullet_texture", bounce_star_textures.pick_random())
		get_tree().current_scene.add_child(star)
func _screen_world_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2(global_position - Vector2(600.0, 600.0), Vector2(1200.0, 1200.0))
	var vis: Rect2 = vp.get_visible_rect()
	var xform: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = xform * Vector2.ZERO
	var b: Vector2 = xform * vis.size
	return Rect2(a, b - a).abs()
