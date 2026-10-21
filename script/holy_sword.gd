extends Area2D
class_name SwordProjectile
enum State{ORBIT, AIM, SPIN_UP, FLY, EMERGE}
@export var sfx_hit: Array[AudioStream] = []
@export var knockback: float = 150.0
@export var orbit_margin: float = 40.0
@export var orbit_speed: float = 0.04
@export var sprite_angle_offset: float = 90.0
@export var charge_time: float = 0.45
@export var charge_spin_speed: float = 18.0
@export var disc_spin_speed: float = 28.0
@export var emerge_time: float = 0.25
@export var emerge_spin_decel: float = 60.0
@export var overshoot: float = 60.0
@export var shake_strength: float = 0.08
var state: int = State.ORBIT
var damage: float = 10.0
var fly_speed: float = 500.0
var fly_accel: float = 1200.0
var fly_max_speed: float = 1600.0
var aim_time: float = 0.5
var search_radius: float = 100.0
var cooldown: float = 3.0
var player_ref: Node2D = null
var bullet_texture: Texture2D = null
var disc_texture: Texture2D = null
var _orbit_t: float = 0.0
var _cooldown_timer: float = 0.0
var _aim_timer: float = 0.0
var _charge_timer: float = 0.0
var _emerge_timer: float = 0.0
var _current_speed: float = 0.0
var _current_spin: float = 0.0
var _disc_visual_spin: float = 0.0
var _fly_dir: Vector2 = Vector2.RIGHT
var _aim_dir: Vector2 = Vector2.RIGHT
var _fly_start: Vector2 = Vector2.ZERO
var _exit_required: float = 0.0
var _exit_progress: float = 0.0
var _was_inside_screen: bool = false
var _edge_shaken: bool = false
var _target: Node2D = null
var _hit_enemies: Array = []
var _sword_sprite: Sprite2D = null
var _disc_sprite: Sprite2D = null
var _emerge_start_pos: Vector2 = Vector2.ZERO
var _emerge_target_pos: Vector2 = Vector2.ZERO
var _emerge_target_rot: float = 0.0
func _ready() -> void :
	add_to_group("Projectile")
	set_process_priority(-100)
	collision_layer = 0
	collision_mask = 4294967295
	monitoring = true
	monitorable = false
	var sword_node: Node = get_node_or_null("Sprite2D")
	if sword_node is Sprite2D:
		_sword_sprite = sword_node as Sprite2D
	var disc_node: Node = get_node_or_null("Sprite2D2")
	if disc_node is Sprite2D:
		_disc_sprite = disc_node as Sprite2D
	if bullet_texture and _sword_sprite:
		_sword_sprite.texture = bullet_texture
	if disc_texture and _disc_sprite:
		_disc_sprite.texture = disc_texture
	if _sword_sprite:
		_sword_sprite.modulate.a = 1.0
	if _disc_sprite:
		_disc_sprite.visible = false
		_disc_sprite.modulate.a = 0.0
		_disc_sprite.rotation = 0.0
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	_cooldown_timer = cooldown * randf()
	_orbit_t = randf()
	global_position = _get_perimeter_point(_orbit_t)
	var dir: Vector2 = _orbit_direction(_orbit_t)
	rotation = dir.angle() + deg_to_rad(sprite_angle_offset)
	_aim_dir = dir
func _process(delta: float) -> void :
	match state:
		State.ORBIT:
			_tick_orbit(delta)
		State.AIM:
			_tick_aim(delta)
		State.SPIN_UP:
			_tick_spin_up(delta)
		State.EMERGE:
			_tick_emerge(delta)
func _physics_process(delta: float) -> void :
	if state == State.FLY:
		_tick_fly(delta)
func _tick_orbit(delta: float) -> void :
	_cooldown_timer -= delta
	_orbit_t = fmod(_orbit_t + orbit_speed * delta, 1.0)
	if _orbit_t < 0.0:
		_orbit_t += 1.0
	global_position = _get_perimeter_point(_orbit_t)
	var dir: Vector2 = _orbit_direction(_orbit_t)
	_aim_dir = dir
	var target_rot: float = dir.angle() + deg_to_rad(sprite_angle_offset)
	rotation = lerp_angle(rotation, target_rot, 20.0 * delta)
	if _cooldown_timer <= 0.0:
		_find_target()
func _orbit_direction(t: float) -> Vector2:
	t = fmod(t, 1.0)
	if t < 0.0:
		t += 1.0
	if t < 0.25:
		return Vector2.RIGHT
	elif t < 0.5:
		return Vector2.DOWN
	elif t < 0.75:
		return Vector2.LEFT
	return Vector2.UP
func _tick_aim(delta: float) -> void :
	_aim_timer -= delta
	if is_instance_valid(_target):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		_aim_dir = dir
		rotation = lerp_angle(rotation, dir.angle() + deg_to_rad(sprite_angle_offset), 12.0 * delta)
	if _aim_timer <= 0.0:
		state = State.SPIN_UP
		_charge_timer = charge_time
		_current_spin = 0.0
		if _sword_sprite:
			_sword_sprite.modulate.a = 1.0
		if _disc_sprite:
			_disc_sprite.visible = false
			_disc_sprite.modulate.a = 0.0
			_disc_sprite.rotation = 0.0
func _tick_spin_up(delta: float) -> void :
	_charge_timer -= delta
	var progress: float = 1.0 - clampf(_charge_timer / charge_time, 0.0, 1.0)
	_current_spin = charge_spin_speed * progress * progress
	rotation += _current_spin * delta
	var fade_start: float = 0.65
	var fade: float = clampf((progress - fade_start) / maxf(1.0 - fade_start, 0.001), 0.0, 1.0)
	if _sword_sprite:
		_sword_sprite.modulate.a = 1.0 - fade
	if _disc_sprite:
		_disc_sprite.visible = fade > 0.0
		_disc_sprite.modulate.a = fade
		_disc_sprite.rotation = 0.0
	if _charge_timer <= 0.0:
		_start_fly()
func _tick_fly(delta: float) -> void :
	_current_speed = minf(_current_speed + fly_accel * delta, fly_max_speed)
	_current_spin = lerpf(_current_spin, disc_spin_speed, 8.0 * delta)
	var move: Vector2 = _fly_dir * _current_speed * delta
	global_position += move
	rotation += _current_spin * delta
	var rect: Rect2 = _screen_world_rect()
	var inside: bool = _rect_has_point(rect, global_position)
	if _was_inside_screen and not inside and not _edge_shaken:
		_shake_camera()
		_edge_shaken = true
	_was_inside_screen = inside
	_exit_progress = (global_position - _fly_start).dot(_fly_dir)
	if _exit_progress >= _exit_required:
		if not _edge_shaken:
			_shake_camera()
			_edge_shaken = true
		_start_emerge()
func _tick_emerge(delta: float) -> void :
	_emerge_timer -= delta
	var progress: float = 1.0 - clampf(_emerge_timer / emerge_time, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	global_position = _emerge_start_pos.lerp(_emerge_target_pos, eased)
	rotation = lerp_angle(rotation, _emerge_target_rot, 10.0 * delta)
	_disc_visual_spin = maxf(_disc_visual_spin - emerge_spin_decel * delta, 0.0)
	if _disc_sprite:
		_disc_sprite.rotation += _disc_visual_spin * delta
		_disc_sprite.modulate.a = 1.0 - eased
		if eased >= 0.98:
			_disc_sprite.visible = false
	if _sword_sprite:
		_sword_sprite.modulate.a = eased
	if _emerge_timer <= 0.0:
		_finish_emerge()
func _find_target() -> void :
	if not is_instance_valid(player_ref):
		return
	var best: Node2D = null
	var best_d: float = INF
	var enemies: Array = get_tree().get_nodes_in_group("Enemy")
	for node in enemies:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d: float = enemy.global_position.distance_to(player_ref.global_position)
		if d > search_radius:
			continue
		if d < best_d:
			best_d = d
			best = enemy
	if best != null:
		_target = best
		_aim_dir = (best.global_position - global_position).normalized()
		state = State.AIM
		_aim_timer = aim_time
	else:
		_cooldown_timer = 0.5
func _start_fly() -> void :
	state = State.FLY
	_current_speed = fly_speed
	_current_spin = charge_spin_speed
	_fly_start = global_position
	_hit_enemies.clear()
	_edge_shaken = false
	var rect: Rect2 = _screen_world_rect()
	_was_inside_screen = _rect_has_point(rect, global_position)
	if is_instance_valid(_target):
		_fly_dir = (_target.global_position - global_position).normalized()
	else:
		_fly_dir = _aim_dir
	if _fly_dir.length_squared() < 0.0001:
		_fly_dir = Vector2.RIGHT
	var edge_distance: float = _ray_exit_distance(global_position, _fly_dir, rect)
	if edge_distance < 0.0:
		edge_distance = 10000.0
	_exit_required = edge_distance + overshoot
	_exit_progress = 0.0
	if _disc_sprite:
		_disc_sprite.visible = true
		_disc_sprite.modulate.a = 1.0
		_disc_sprite.rotation = 0.0
	if _sword_sprite:
		_sword_sprite.modulate.a = 0.0
func _start_emerge() -> void :
	state = State.EMERGE
	_emerge_timer = emerge_time
	_emerge_start_pos = global_position
	_orbit_t = _position_to_orbit_t(global_position)
	_emerge_target_pos = _get_perimeter_point(_orbit_t)
	_emerge_target_rot = _orbit_direction(_orbit_t).angle() + deg_to_rad(sprite_angle_offset)
	_disc_visual_spin = _current_spin
func _finish_emerge() -> void :
	state = State.ORBIT
	_cooldown_timer = cooldown
	_current_speed = fly_speed
	_current_spin = 0.0
	_disc_visual_spin = 0.0
	_hit_enemies.clear()
	_target = null
	_edge_shaken = false
	_was_inside_screen = false
	global_position = _emerge_target_pos
	rotation = _emerge_target_rot
	if _sword_sprite:
		_sword_sprite.modulate.a = 1.0
	if _disc_sprite:
		_disc_sprite.visible = false
		_disc_sprite.modulate.a = 0.0
		_disc_sprite.rotation = 0.0
func _ray_exit_distance(origin: Vector2, dir: Vector2, rect: Rect2) -> float:
	if dir.length_squared() < 0.0001:
		return -1.0
	var tmin: float = - INF
	var tmax: float = INF
	var eps: float = 0.0001
	if absf(dir.x) < eps:
		if origin.x < rect.position.x or origin.x > rect.end.x:
			return -1.0
	else:
		var tx1: float = (rect.position.x - origin.x) / dir.x
		var tx2: float = (rect.end.x - origin.x) / dir.x
		tmin = maxf(tmin, minf(tx1, tx2))
		tmax = minf(tmax, maxf(tx1, tx2))
	if absf(dir.y) < eps:
		if origin.y < rect.position.y or origin.y > rect.end.y:
			return -1.0
	else:
		var ty1: float = (rect.position.y - origin.y) / dir.y
		var ty2: float = (rect.end.y - origin.y) / dir.y
		tmin = maxf(tmin, minf(ty1, ty2))
		tmax = minf(tmax, maxf(ty1, ty2))
	if tmax < 0.0 or tmax < tmin:
		return -1.0
	return tmax
func _screen_world_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2(global_position - Vector2(600.0, 600.0), Vector2(1200.0, 1200.0))
	var vis: Rect2 = vp.get_visible_rect()
	var xform: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = xform * Vector2.ZERO
	var b: Vector2 = xform * vis.size
	return Rect2(a, b - a).abs()
func _rect_has_point(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x - 0.5 and point.x <= rect.end.x + 0.5 and point.y >= rect.position.y - 0.5 and point.y <= rect.end.y + 0.5
func _get_perimeter_point(t: float) -> Vector2:
	var rect: Rect2 = _screen_world_rect()
	var half: Vector2 = rect.size / 2.0 + Vector2(orbit_margin, orbit_margin)
	var center: Vector2 = rect.position + rect.size / 2.0
	var top_left: Vector2 = center - half
	t = fmod(t, 1.0)
	if t < 0.0:
		t += 1.0
	var w: float = half.x * 2.0
	var h: float = half.y * 2.0
	if t < 0.25:
		return top_left + Vector2(t / 0.25 * w, 0.0)
	elif t < 0.5:
		return top_left + Vector2(w, (t - 0.25) / 0.25 * h)
	elif t < 0.75:
		return top_left + Vector2(w - (t - 0.5) / 0.25 * w, h)
	return top_left + Vector2(0.0, h - (t - 0.75) / 0.25 * h)
func _position_to_orbit_t(pos: Vector2) -> float:
	var rect: Rect2 = _screen_world_rect()
	var half: Vector2 = rect.size / 2.0 + Vector2(orbit_margin, orbit_margin)
	var center: Vector2 = rect.position + rect.size / 2.0
	var top_left: Vector2 = center - half
	var w: float = half.x * 2.0
	var h: float = half.y * 2.0
	var rel: Vector2 = pos - top_left
	var best_t: float = 0.0
	var best_d: float = INF
	var candidates: Array[Vector2] = [
		Vector2(clampf(rel.x, 0.0, w), 0.0), 
		Vector2(w, clampf(rel.y, 0.0, h)), 
		Vector2(clampf(rel.x, 0.0, w), h), 
		Vector2(0.0, clampf(rel.y, 0.0, h))
	]
	for i in range(candidates.size()):
		var cand: Vector2 = candidates[i]
		var d: float = rel.distance_squared_to(cand)
		if d < best_d:
			best_d = d
			match i:
				0:
					best_t = (cand.x / w) * 0.25
				1:
					best_t = 0.25 + (cand.y / h) * 0.25
				2:
					best_t = 0.5 + ((w - cand.x) / w) * 0.25
				3:
					best_t = 0.75 + ((h - cand.y) / h) * 0.25
	return best_t
func _shake_camera() -> void :
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
		return
	var base: Vector2 = cam.offset
	var tw: Tween = cam.create_tween()
	for i in range(6):
		var amp: float = shake_strength * 32.0 * (1.0 - float(i) / 6.0)
		tw.tween_property(cam, "offset", base + Vector2(randf_range( - amp, amp), randf_range( - amp, amp)), 0.03)
	tw.tween_property(cam, "offset", base, 0.05)
func _on_body_entered(body: Node2D) -> void :
	if state != State.FLY:
		return
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	_hit(body)
func _on_area_entered(area: Area2D) -> void :
	if state != State.FLY:
		return
	var target: Node = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	_hit(target)
func _hit(target: Node) -> void :
	if _hit_enemies.has(target):
		return
	_hit_enemies.append(target)
	var final_damage: float = damage
	if player_ref != null and "might" in player_ref:
		final_damage *= player_ref.might
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		var enemy_target: Node2D = target as Node2D
		enemy_target.knockback = _fly_dir * knockback
	_play_hit_sfx()
func _play_hit_sfx() -> void :
	if sfx_hit.is_empty():
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var sound: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	sound.stream = sfx_hit.pick_random()
	sound.volume_db = -10.0
	sound.pitch_scale = randf_range(0.7, 1.1)
	sound.global_position = global_position
	scene.add_child(sound)
	sound.play()
	sound.finished.connect( func(): sound.queue_free())
