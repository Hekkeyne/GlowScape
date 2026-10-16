extends Area2D
class_name SawstormDisc

@export var sfx: Array[AudioStream] = []
@export var explosion_sprite: Texture2D = null
@export_range(50.0, 1000.0, 10.0) var base_speed: float = 220.0
@export_range(100.0, 3000.0, 50.0) var max_speed: float = 900.0
@export_range(500.0, 8000.0, 100.0) var steer_accel: float = 2600.0
@export_range(0.0, 200.0, 5.0) var passive_boost: float = 30.0
@export_range(0.0, 300.0, 10.0) var hit_speed_boost: float = 70.0
@export_range(50.0, 1500.0, 10.0) var bounce_speed: float = 450.0
@export_range(-0.5, 0.9, 0.05) var bounce_prefer_dot: float = 0.2
@export_range(0.0, 2.0, 0.05) var rehit_delay: float = 0.3
@export_range(0.0, 3.0, 0.1) var search_cooldown: float = 0.5
@export_range(4.0, 100.0, 2.0) var hit_radius: float = 8.0:
	set(v):
		hit_radius = v
		_sync_radius()
@export_range(0.0, 800.0, 10.0) var knockback_force: float = 220.0
@export_range(1.0, 5.0, 0.1) var damage_speed_mult: float = 2.0
@export_range(1.0, 5.0, 0.1) var knockback_speed_mult: float = 2.0
@export_range(0.0, 0.5, 0.02) var lead_time: float = 0.12
@export_range(0.05, 1.0, 0.05) var shrink_time: float = 0.25
@export_range(200.0, 3000.0, 50.0) var leash_radius: float = 900.0
@export_range(0.0, 1.0, 0.05) var bounce_back_mix: float = 0.35
@export_range(0.0, 1.0, 0.05) var bounce_aim_mix: float = 0.4
@export_range(0.0, 0.6, 0.02) var bounce_spread: float = 0.18
@export_range(0.05, 1.0, 0.05) var flash_time: float = 0.15
@export var edge_bounce: bool = true
@export_range(0.5, 1.0, 0.01) var decay_threshold: float = 0.75
@export_range(0.0, 1000.0, 25.0) var decay_drag: float = 180.0
@export_range(20.0, 200.0, 5.0) var explosion_base_radius: float = 60.0
@export_range(0.0, 3.0, 0.1) var explosion_speed_mult: float = 1.5
@export_range(0.0, 2.0, 0.05) var explosion_damage_mult: float = 0.8
@export_range(0.0, 600.0, 10.0) var explosion_knockback: float = 200.0
@export_range(0.0, 3.0, 0.1) var explosion_knockback_speed_mult: float = 1.8

var damage: float = 1.0
var source = null
var owner_weapon = null
var vel: Vector2 = Vector2.ZERO
var current_max: float = 0.0
var target: Node2D = null
var last_hit: Node2D = null
var bounce_dir: Vector2 = Vector2.ZERO
var state: String = "seek"
var state_timer: float = 0.0
var age: float = 0.0
var dying_timer: float = 0.0
var flash: float = 0.0
var _hit_times: Dictionary = {}
var _base_scale: Vector2 = Vector2.ONE
var _grace: float = 0.0

static var _enemy_cache: Array = []
static var _enemy_cache_frame: int = -1
static var _fallback_tex: Texture2D = null

var speed:
	set(v):
		base_speed = float(v)
		current_max = maxf(current_max, base_speed)
	get:
		return base_speed

var net_id: int = 0

func _ready() -> void:
	add_to_group("Projectile")
	_base_scale = scale
	current_max = base_speed
	_grace = 0.15
	_setup_collision()
	target = _pick_target(null, Vector2.ZERO)
	if target == null:
		state = "search"
		state_timer = search_cooldown

func _setup_collision() -> void:
	_sync_radius()
	collision_layer = 0
	collision_mask = 4294967295
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _sync_radius() -> void:
	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = hit_radius

func _enemies() -> Array:
	var f = Engine.get_process_frames()
	if _enemy_cache_frame != f:
		_enemy_cache = get_tree().get_nodes_in_group("Enemy")
		_enemy_cache_frame = f
	return _enemy_cache

func _physics_process(delta: float) -> void:
	age += delta
	_grace = maxf(0.0, _grace - delta)
	flash = maxf(0.0, flash - delta / flash_time)
	current_max = minf(current_max + passive_boost * delta, max_speed)
	if vel.length() >= max_speed * decay_threshold:
		vel = vel.move_toward(Vector2.ZERO, decay_drag * delta)
	if state == "dying":
		_tick_dying(delta)
		return
	modulate = Color(1.0 + 2.5 * flash, 1.0 + 2.5 * flash, 1.0 + 2.5 * flash, 1.0)
	if source != null and is_instance_valid(source) and global_position.distance_to(source.global_position) > leash_radius:
		_start_dying()
		return
	match state:
		"seek":
			_tick_seek(delta)
		"search":
			vel = vel.move_toward(Vector2.ZERO, steer_accel * 0.4 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				var t = last_hit if is_instance_valid(last_hit) else null
				if t == null:
					t = _pick_target(null, bounce_dir)
				target = t
				if target != null:
					state = "seek"
				else:
					state_timer = search_cooldown
	var prev_pos = global_position
	global_position += vel * delta
	if edge_bounce:
		_wall_bounce()
	_sweep_hit(prev_pos, global_position)
	if vel.length_squared() > 1.0:
		rotation = vel.angle()

func _tick_seek(delta: float) -> void:
	if not is_instance_valid(target):
		target = _pick_target(last_hit if is_instance_valid(last_hit) else null, bounce_dir)
		if target == null:
			state = "search"
			state_timer = search_cooldown
			return
	var aim = target.global_position
	if "velocity" in target:
		aim += target.velocity * lead_time
	var to = aim - global_position
	var dist = to.length()
	if dist > 0.01:
		var desired = (to / dist) * current_max
		vel = vel.move_toward(desired, steer_accel * delta)

func _wall_bounce() -> void:
	var r = _screen_rect()
	var m = _bound_margin()
	var bounced := false
	if global_position.x < r.position.x + m:
		global_position.x = r.position.x + m
		if vel.x < 0:
			vel.x = -vel.x
		bounced = true
	elif global_position.x > r.end.x - m:
		global_position.x = r.end.x - m
		if vel.x > 0:
			vel.x = -vel.x
		bounced = true
	if global_position.y < r.position.y + m:
		global_position.y = r.position.y + m
		if vel.y < 0:
			vel.y = -vel.y
		bounced = true
	elif global_position.y > r.end.y - m:
		global_position.y = r.end.y - m
		if vel.y > 0:
			vel.y = -vel.y
		bounced = true
	if bounced:
		flash = maxf(flash, 0.4)

func _bound_margin() -> float:
	return hit_radius + 6.0

func _screen_rect() -> Rect2:
	var vp = get_viewport()
	var vis = vp.get_visible_rect()
	var xform = vp.get_canvas_transform().affine_inverse()
	var a = xform * Vector2.ZERO
	var b = xform * vis.size
	return Rect2(a, b - a).abs()

func _sweep_hit(prev: Vector2, cur: Vector2) -> void:
	if state == "dying":
		return
	var seg = cur - prev
	if seg.length_squared() < 1.0:
		return
	var minx = minf(prev.x, cur.x) - hit_radius
	var maxx = maxf(prev.x, cur.x) + hit_radius
	var miny = minf(prev.y, cur.y) - hit_radius
	var maxy = maxf(prev.y, cur.y) + hit_radius
	for e in _enemies():
		if not is_instance_valid(e) or not e is Node2D:
			continue
		if "is_dying" in e and e.is_dying:
			continue
		var p = e.global_position
		if p.x < minx or p.x > maxx or p.y < miny or p.y > maxy:
			continue
		var closest = Geometry2D.get_closest_point_to_segment(p, prev, cur)
		var r = hit_radius + _enemy_radius(e)
		if p.distance_squared_to(closest) <= r * r:
			_try_hit(e)
			return

func _enemy_radius(e: Node2D) -> float:
	var r = e.get("hit_radius")
	if r == null:
		r = e.get("radius")
	if r == null:
		return 16.0
	return float(r)

func _on_body_entered(body: Node2D) -> void:
	if state == "dying" or body == source:
		return
	if body.has_method("take_damage"):
		_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if state == "dying":
		return
	var parent = area.get_parent()
	if parent == self or parent == source:
		return
	if parent.has_method("take_damage"):
		_try_hit(parent)

func _try_hit(enemy: Node2D) -> void:
	if _grace > 0.0:
		return
	var id = enemy.get_instance_id()
	if _hit_times.has(id) and age - _hit_times[id] < rehit_delay:
		return
	_on_hit(enemy)

func _on_hit(enemy: Node2D) -> void:
	_hit_times[enemy.get_instance_id()] = age
	var spd_t = clampf(vel.length() / max_speed, 0.0, 1.0)
	last_hit = enemy
	var incoming = vel.normalized()
	var dmg = damage * lerpf(1.0, damage_speed_mult, spd_t)
	var kb = knockback_force * lerpf(1.0, knockback_speed_mult, spd_t)
	enemy.take_damage(dmg * _might())
	if "knockback" in enemy:
		enemy.knockback = incoming * kb
	bounce_dir = _bounce_direction(enemy)
	_play_hit_sfx()
	flash = 1.0
	current_max = minf(current_max + hit_speed_boost, max_speed)
	vel = bounce_dir * maxf(bounce_speed, current_max)
	global_position += bounce_dir * 2.0
	_spawn_explosion(enemy.global_position, spd_t, dmg)
	if owner_weapon != null and owner_weapon.has_method("on_disc_hit"):
		owner_weapon.on_disc_hit(self, global_position)
	var next = _pick_target(enemy, bounce_dir)
	if next != null:
		target = next
		state = "seek"
	else:
		target = null
		state = "search"
		state_timer = search_cooldown

func _spawn_explosion(pos: Vector2, spd_t: float, base_dmg: float) -> void:
	var radius = explosion_base_radius * lerpf(1.0, explosion_speed_mult, spd_t)
	var dmg = base_dmg * explosion_damage_mult * _might()
	var kb = explosion_knockback * lerpf(1.0, explosion_knockback_speed_mult, spd_t)
	for node in _enemies():
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var d = node.global_position.distance_to(pos)
		if d > radius:
			continue
		var falloff = 1.0 - (d / radius) * 0.5
		node.take_damage(dmg * falloff)
		if "knockback" in node:
			var push = (node.global_position - pos).normalized()
			node.knockback = push * kb * falloff
	var expl = Sprite2D.new()
	expl.texture = _explosion_texture()
	expl.global_position = pos
	expl.z_index = 10
	expl.scale = Vector2(0.3, 0.3)
	expl.modulate = Color(2.0, 2.0, 2.0, 1.0)
	get_tree().current_scene.add_child(expl)
	var tw = expl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(expl, "scale", Vector2(radius / 32.0, radius / 32.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(expl, "modulate:a", 0.0, 0.25)
	tw.finished.connect(expl.queue_free)

func _explosion_texture() -> Texture2D:
	if explosion_sprite:
		return explosion_sprite
	if _fallback_tex == null:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d = Vector2(x - 31.5, y - 31.5).length() / 32.0
				var a = clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.75, 0.3, a * a))
		_fallback_tex = ImageTexture.create_from_image(img)
	return _fallback_tex

func _bounce_direction(enemy: Node2D) -> Vector2:
	var normal = global_position - enemy.global_position
	if normal.length_squared() < 0.01:
		normal = -vel
	if normal.length_squared() < 0.01:
		normal = Vector2.RIGHT
	normal = normal.normalized()
	var incoming = vel.normalized()
	if incoming.length_squared() < 0.01:
		incoming = -normal
	var reflected = (incoming - 2.0 * incoming.dot(normal) * normal).normalized()
	var dir = reflected.lerp(normal, bounce_back_mix).normalized()
	var side = _pick_target(enemy, dir)
	if side != null:
		var to_side = (side.global_position - global_position).normalized()
		if to_side.dot(dir) > -0.3:
			dir = dir.lerp(to_side, bounce_aim_mix).normalized()
	dir = dir.rotated(randf_range(-bounce_spread, bounce_spread))
	return dir

func _might() -> float:
	if source != null and "might" in source:
		return source.might
	return 1.0

func _pick_target(exclude: Node2D, prefer_dir: Vector2) -> Node2D:
	var best_front: Node2D = null
	var best_front_d: float = INF
	var best_any: Node2D = null
	var best_any_d: float = INF
	var use_cone = prefer_dir.length_squared() > 0.5
	for node in _enemies():
		if not is_instance_valid(node) or node == exclude:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var d = global_position.distance_squared_to(node.global_position)
		if d < best_any_d:
			best_any_d = d
			best_any = node
		if use_cone and d < best_front_d:
			var dir = (node.global_position - global_position).normalized()
			if dir.dot(prefer_dir) > bounce_prefer_dot:
				best_front_d = d
				best_front = node
	return best_front if best_front != null else best_any

func _start_dying() -> void:
	if state == "dying":
		return
	state = "dying"
	dying_timer = shrink_time

func _tick_dying(delta: float) -> void:
	dying_timer -= delta
	var t = clampf(dying_timer / shrink_time, 0.0, 1.0)
	scale = _base_scale * maxf(t, 0.01)
	modulate.a = t
	vel = vel.move_toward(Vector2.ZERO, steer_accel * 0.5 * delta)
	global_position += vel * delta
	if dying_timer <= 0.0:
		queue_free()

func _play_hit_sfx() -> void:
	if sfx.is_empty() or not has_node("AudioStreamPlayer2D"):
		return
	$AudioStreamPlayer2D.stream = sfx.pick_random()
	$AudioStreamPlayer2D.pitch_scale = randf_range(0.7, 1.3)
	$AudioStreamPlayer2D.play()

func set_base(new_base: float) -> void:
	base_speed = new_base
	current_max = maxf(current_max, new_base)
