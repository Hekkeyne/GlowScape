class_name LaserBeam
extends Node2D
@export var hit_sound: AudioStream = null
@export_range(0.0, 2.0, 0.05) var hit_sound_cooldown: float = 0.15
var _hit_audio: AudioStreamPlayer2D = null
var _hit_sound_timer: float = 0.0
var muzzle: Node2D = null
var source: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var spin_speed: float = 0.0
var max_reflections: int = 2
var damage: float = 10.0
var duration: float = 0.4
var grow_time: float = 0.12
var rehit_interval: float = 0.0
var hit_radius: float = 40.0

var glow_line: Line2D
var core_line: Line2D
var full_points: PackedVector2Array
var path_lengths: PackedFloat32Array
var total_length: float = 0.0
var life_timer: float = 0.0
var hit_enemies: Dictionary = {}

func setup(p_muzzle: Node2D, p_source: Node2D, p_dir: Vector2, p_reflections: int, p_damage: float, p_duration: float, p_grow: float) -> void:
	muzzle = p_muzzle
	source = p_source
	direction = p_dir
	max_reflections = p_reflections
	damage = p_damage
	duration = p_duration
	grow_time = p_grow
	life_timer = p_duration

var net_id: int = 0

func _ready() -> void:
	add_to_group("Projectile")
	glow_line = get_node_or_null("Glow")
	if glow_line == null:
		glow_line = Line2D.new()
		glow_line.name = "Glow"
		glow_line.width = 26.0
		glow_line.default_color = Color(0.3, 0.7, 1.0, 0.35)
		add_child(glow_line)
	core_line = get_node_or_null("Core")
	if core_line == null:
		core_line = Line2D.new()
		core_line.name = "Core"
		core_line.width = 6.0
		core_line.default_color = Color(1.0, 1.0, 1.0, 1.0)
		add_child(core_line)
	z_index = 50
	_rebuild_path()
	if hit_sound != null:
		_hit_audio = AudioStreamPlayer2D.new()
		_hit_audio.stream = hit_sound
		_hit_audio.bus = "Master"
		add_child(_hit_audio)

func _process(delta: float) -> void:
	life_timer -= delta
	if _hit_sound_timer > 0.0:
		_hit_sound_timer -= delta
	if life_timer <= 0.0:
		queue_free()
		return
	if not is_instance_valid(source):
		queue_free()
		return
	if spin_speed != 0.0:
		direction = direction.rotated(spin_speed * delta)
	_rebuild_path()
	var elapsed = duration - life_timer
	var progress: float = 1.0
	if grow_time > 0.0:
		progress = clampf(elapsed / grow_time, 0.0, 1.0)
	_update_points(progress)
	if progress >= 1.0:
		_deal_damage()
	modulate.a = lerpf(0.1, 1.0, clampf(life_timer / duration, 0.0, 1.0))

func _update_points(progress: float) -> void:
	if full_points.size() < 2:
		return
	var target_len = total_length * progress
	var pts = PackedVector2Array()
	pts.append(full_points[0])
	var acc = float(0.0)
	for i in range(1, full_points.size()):
		var seg_len = path_lengths[i - 1]
		if acc + seg_len <= target_len:
			pts.append(full_points[i])
			acc += seg_len
		else:
			var remain = target_len - acc
			var seg_dir = (full_points[i] - full_points[i - 1]).normalized()
			pts.append(full_points[i - 1] + seg_dir * remain)
			break
	glow_line.points = pts
	core_line.points = pts

func _rebuild_path() -> void:
	var start: Vector2
	if is_instance_valid(muzzle):
		start = muzzle.global_position
	else:
		start = source.global_position
	global_position = start
	full_points = PackedVector2Array()
	full_points.append(Vector2.ZERO)
	var cur_pos = start
	var cur_dir = direction
	var rect = _screen_rect()
	for i in range(max_reflections + 1):
		var hit = _intersect_bounds(cur_pos, cur_dir, rect)
		if hit.t == INF:
			break
		var hit_pos = cur_pos + cur_dir * hit.t
		full_points.append(hit_pos - start)
		cur_pos = hit_pos
		cur_dir = (cur_dir - 2.0 * cur_dir.dot(hit.normal) * hit.normal).normalized()
	path_lengths = PackedFloat32Array()
	total_length = 0.0
	for i in range(1, full_points.size()):
		var l = full_points[i].distance_to(full_points[i - 1])
		path_lengths.append(l)
		total_length += l

func _screen_rect() -> Rect2:
	var vp = get_viewport()
	var vis = vp.get_visible_rect()
	var xform = vp.get_canvas_transform().affine_inverse()
	var a = xform * Vector2.ZERO
	var b = xform * vis.size
	return Rect2(a, b - a)

func _intersect_bounds(pos: Vector2, dir: Vector2, rect: Rect2) -> Dictionary:
	var best_t: float = INF
	var best_normal: Vector2 = Vector2.ZERO
	var sides = [
		[0, rect.position.x, Vector2(-1, 0)],
		[0, rect.end.x, Vector2(1, 0)],
		[1, rect.position.y, Vector2(0, -1)],
		[1, rect.end.y, Vector2(0, 1)],
	]
	for s in sides:
		var d = dir[s[0]]
		if absf(d) < 0.0001:
			continue
		var t = (s[1] - pos[s[0]]) / d
		if t <= 0.001:
			continue
		var other = 1 - s[0]
		var hit_other = pos[other] + dir[other] * t
		if hit_other < rect.position[other] - 0.1 or hit_other > rect.end[other] + 0.1:
			continue
		if t < best_t:
			best_t = t
			best_normal = s[2]
	return {"t": best_t, "normal": best_normal}

func _deal_damage() -> void:
	var elapsed = duration - life_timer
	var hit_this_frame = false
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D or enemy == source:
			continue
		var local = enemy.global_position - global_position
		var closest = _closest_point_on_path(local)
		if closest == Vector2.INF:
			continue
		if local.distance_to(closest) < hit_radius:
			if hit_enemies.has(enemy):
				if rehit_interval <= 0.0 or elapsed - hit_enemies[enemy] < rehit_interval:
					continue
			hit_enemies[enemy] = elapsed
			hit_this_frame = true
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
	if hit_this_frame and _hit_audio != null and _hit_sound_timer <= 0.0:
		_hit_audio.global_position = global_position
		_hit_audio.play()
		_hit_sound_timer = hit_sound_cooldown

func _closest_point_on_path(point: Vector2) -> Vector2:
	var best_dist: float = INF
	var best_point: Vector2 = Vector2.INF
	for i in range(full_points.size() - 1):
		var a = full_points[i]
		var b = full_points[i + 1]
		var ab = b - a
		var len2 = ab.length_squared()
		if len2 < 0.001:
			continue
		var t = clampf((point - a).dot(ab) / len2, 0.0, 1.0)
		var p = a + ab * t
		var d = point.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best_point = p
	return best_point
