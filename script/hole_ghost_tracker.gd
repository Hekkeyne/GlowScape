extends Node
class_name HoleGhostTracker

@export_range(0.0, 3.0, 0.05) var eject_delay: float = 0.8
@export_range(0.0, 4.0, 0.05) var eject_window: float = 1.6
@export_range(0.0, 2.0, 0.05) var portal_telegraph: float = 0.6
@export_range(0.2, 3.0, 0.05) var portal_fade: float = 0.9
@export_range(0.0, 1.0, 0.05) var exit_restore_window: float = 0.15
@export_range(16.0, 200.0, 4.0) var portal_min_sep: float = 60.0
@export var use_duration_trigger: bool = true

var _hole: Node2D = null
var _orig_mask: Dictionary = {}
var _in_hole: Array = []
var _pending_restore: Array = []
var _pending_eject: Array = []
var _pending_appear: Array = []
var _used_pos: Array = []
var _released: bool = false
var _life: float = 0.0
var _eat_radius: float = 0.0
var _portal_tex: Texture2D = null

func _ready() -> void :
	_hole = get_parent() as Node2D
	if _hole != null:
		for prop in ["swirl_texture", "rim_texture", "core_texture"]:
			if prop in _hole and _hole.get(prop) != null:
				_portal_tex = _hole.get(prop)
				break

func _hole_dying() -> bool:
	if not is_instance_valid(_hole):
		return true
	if _hole.is_queued_for_deletion():
		return true
	return use_duration_trigger and ("duration" in _hole) and _life >= _hole.duration

func _physics_process(delta: float) -> void :
	_life += delta
	if not _released and _hole_dying():
		_release()
	if not _released and is_instance_valid(_hole) and "pull_radius" in _hole:
		_track_hole()
	_process_ejects(delta)
	_process_appears(delta)
	_process_restores(delta)
	if _released and _pending_eject.is_empty() and _pending_appear.is_empty() and _pending_restore.is_empty():
		queue_free()

func _track_hole() -> void :
	var r2 = _hole.pull_radius * _hole.pull_radius
	_eat_radius = maxf(_eat_radius, _hole.pull_radius)
	var pos = _hole.global_position
	var now_in: Array = []
	for e in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(e) or not ("collision_mask" in e):
			continue
		if e.global_position.distance_squared_to(pos) <= r2:
			if not _orig_mask.has(e):
				_orig_mask[e] = e.collision_mask
				e.collision_mask = 0
			_cancel_restore(e)
			now_in.append(e)
	if not _hole_dying():
		for e in _in_hole:
			if is_instance_valid(e) and not now_in.has(e) and _orig_mask.has(e):
				_pending_restore.append({"e": e, "t": randf_range(0.0, exit_restore_window)})
	_in_hole = now_in

func _release() -> void :
	_released = true
	if not is_instance_valid(_hole):
		_restore_all_now()
		return
	var parent = _hole.get_parent()
	if parent != null and get_parent() != parent:
		reparent(parent)
	var center = _hole.global_position
	var eat_r2 = _eat_radius * _eat_radius
	var eaten: Dictionary = {}
	for e in _in_hole:
		eaten[e] = true
	for p in _pending_restore:
		eaten[p.e] = true
	_pending_restore.clear()
	for e in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_squared_to(center) <= eat_r2:
			eaten[e] = true
	for e in eaten:
		if not is_instance_valid(e) or not ("collision_mask" in e):
			continue
		if not _orig_mask.has(e):
			_orig_mask[e] = e.collision_mask
		e.collision_mask = 0
		e.visible = false
		_pending_eject.append({"e": e, "t": eject_delay + randf_range(0.0, eject_window), "pos": _random_screen_pos()})
	_in_hole.clear()

func _process_ejects(delta: float) -> void :
	for idx in range(_pending_eject.size() - 1, -1, -1):
		var p = _pending_eject[idx]
		p.t -= delta
		if p.t <= 0.0:
			if is_instance_valid(p.e):
				_spawn_portal(p.pos)
				_pending_appear.append({"e": p.e, "pos": p.pos, "t": portal_telegraph})
			_pending_eject.remove_at(idx)

func _process_appears(delta: float) -> void :
	for idx in range(_pending_appear.size() - 1, -1, -1):
		var p = _pending_appear[idx]
		p.t -= delta
		if p.t <= 0.0:
			var e = p.e
			if is_instance_valid(e):
				e.global_position = p.pos
				e.visible = true
				if _orig_mask.has(e):
					e.collision_mask = _orig_mask[e]
					_orig_mask.erase(e)
			_pending_appear.remove_at(idx)

func _process_restores(delta: float) -> void :
	for idx in range(_pending_restore.size() - 1, -1, -1):
		var p = _pending_restore[idx]
		p.t -= delta
		if p.t <= 0.0:
			if is_instance_valid(p.e) and _orig_mask.has(p.e):
				p.e.collision_mask = _orig_mask[p.e]
				_orig_mask.erase(p.e)
			_pending_restore.remove_at(idx)

func _random_screen_pos() -> Vector2:
	var size = get_viewport().get_visible_rect().size
	var center: Vector2
	var half: Vector2
	var cam = get_viewport().get_camera_2d()
	if cam != null:
		center = cam.global_position
		half = (size * 0.5) / cam.zoom * 0.85
	else:
		center = size * 0.5
		half = size * 0.5 * 0.85
	var best: Vector2 = center
	for _try in range(6):
		var candidate = center + Vector2(randf_range( - half.x, half.x), randf_range( - half.y, half.y))
		best = candidate
		var ok = true
		for used in _used_pos:
			if candidate.distance_squared_to(used) < portal_min_sep * portal_min_sep:
				ok = false
				break
		if ok:
			break
	_used_pos.append(best)
	return best

func _spawn_portal(pos: Vector2) -> void :
	if _portal_tex == null:
		return
	var s = Sprite2D.new()
	s.texture = _portal_tex
	s.global_position = pos
	s.modulate = Color(1, 1, 1, 0.9)
	s.scale = Vector2(0.3, 0.3)
	get_tree().current_scene.add_child(s)
	var tw = s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "rotation", TAU * 1.5, portal_telegraph + portal_fade)
	tw.tween_property(s, "scale", Vector2(1.4, 1.4), portal_telegraph).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, portal_fade).set_delay(portal_telegraph)
	tw.finished.connect(s.queue_free)

func _cancel_restore(e: Node) -> void :
	for idx in range(_pending_restore.size() - 1, -1, -1):
		if _pending_restore[idx].e == e:
			_pending_restore.remove_at(idx)

func _restore_all_now() -> void :
	for p in _pending_eject:
		if is_instance_valid(p.e):
			p.e.visible = true
			if _orig_mask.has(p.e):
				p.e.collision_mask = _orig_mask[p.e]
	for p in _pending_appear:
		if is_instance_valid(p.e):
			p.e.visible = true
			if _orig_mask.has(p.e):
				p.e.collision_mask = _orig_mask[p.e]
	for p in _pending_restore:
		if is_instance_valid(p.e) and _orig_mask.has(p.e):
			p.e.collision_mask = _orig_mask[p.e]
	for e in _in_hole:
		if is_instance_valid(e) and _orig_mask.has(e):
			e.collision_mask = _orig_mask[e]
	_orig_mask.clear()
	_pending_eject.clear()
	_pending_appear.clear()
	_pending_restore.clear()
	_in_hole.clear()

func _exit_tree() -> void :
	_restore_all_now()
