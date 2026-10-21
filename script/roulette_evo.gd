extends Weapon
class_name RouletteEvolution

@export_range(2, 16) var base_sectors: int = 8
@export_range(0.1, 1.5, 0.05) var appear_time: float = 0.4
@export_range(0.5, 6.0, 0.1) var fill_time: float = 2.0
@export_range(0.05, 1.0, 0.05) var lock_time: float = 0.25
@export_range(0.1, 1.0, 0.05) var lock_alpha: float = 0.5
@export_range(0.0, 2.0, 0.05) var strike_hold: float = 0.3
@export_range(0.1, 2.0, 0.05) var strike_fade: float = 0.3
@export_range(0.1, 1.5, 0.05) var disappear_time: float = 0.4
@export_range(0.05, 0.5, 0.05) var highlight_alpha: float = 0.18
@export_range(0.0, 1000.0, 50.0) var strike_knockback: float = 300.0

enum State{IDLE, APPEARING, FILLING, LOCK, STRIKING, DISAPPEARING}
var state: int = State.IDLE
var appear_timer: float = 0.0
var fill_timer: float = 0.0
var lock_timer: float = 0.0
var strike_timer: float = 0.0
var disappear_timer: float = 0.0
var base_rotation: float = 0.0
var start_index: int = 0
var lit_count: int = 0
var active_radius: float = 1000.0

var visual: RouletteVisual = null
var source_ref: CharacterBody2D = null
var tree_ref: SceneTree = null

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if state != State.IDLE:
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	source_ref = source
	tree_ref = scene_tree
	if is_instance_valid(visual):
		visual.queue_free()
	visual = RouletteVisual.new()
	visual.z_index = 100
	scene_tree.current_scene.add_child(visual)
	visual.sector_count = base_sectors
	active_radius = _screen_radius()
	visual.radius = active_radius
	visual.highlight_alpha = highlight_alpha
	visual.lit_alpha = highlight_alpha
	visual.fill_texture = texture
	visual.per_line_mode = false
	visual.sweep_active = false
	visual.line_progress = 0.0
	visual.line_alpha = 1.0
	base_rotation = - PI / 2.0 - (TAU / base_sectors) / 2.0
	visual.base_rotation = base_rotation
	visual.highlight_index = -1
	visual.strike_index = -1
	visual.lit_sectors.clear()
	visual.red_sectors.clear()
	start_index = randi_range(0, base_sectors - 1)
	lit_count = 0
	visual.global_position = source_ref.global_position
	visual.queue_redraw()
	appear_timer = 0.0
	state = State.APPEARING

func update(delta):
	match state:
		State.IDLE:
			return
		State.APPEARING:
			if not is_instance_valid(visual) or not is_instance_valid(source_ref):
				_kill_visual()
				state = State.IDLE
				return
			visual.global_position = source_ref.global_position
			appear_timer += delta
			var p = clampf(appear_timer / appear_time, 0.0, 1.0)
			visual.line_progress = p * p * (3.0 - 2.0 * p)
			visual.queue_redraw()
			if p >= 1.0:
				fill_timer = 0.0
				state = State.FILLING
		State.FILLING:
			if not is_instance_valid(visual) or not is_instance_valid(source_ref):
				_kill_visual()
				state = State.IDLE
				return
			visual.global_position = source_ref.global_position
			fill_timer += delta
			var p = clampf(fill_timer / fill_time, 0.0, 1.0)
			var eased = p * p * (3.0 - 2.0 * p)
			var count = mini(int(eased * (base_sectors + 1)), base_sectors)
			if count != lit_count:
				lit_count = count
				visual.lit_sectors.clear()
				for i in range(lit_count):
					visual.lit_sectors.append((start_index + i) % base_sectors)
				visual.queue_redraw()
			if p >= 1.0:
				state = State.LOCK
				lock_timer = 0.0
		State.LOCK:
			if not is_instance_valid(visual) or not is_instance_valid(source_ref):
				_kill_visual()
				state = State.IDLE
				return
			visual.global_position = source_ref.global_position
			lock_timer += delta
			var q = clampf(lock_timer / (lock_time * 0.35), 0.0, 1.0)
			visual.lit_alpha = lerpf(highlight_alpha, lock_alpha, q)
			visual.queue_redraw()
			if lock_timer >= lock_time:
				_start_strike()
		State.STRIKING:
			if not is_instance_valid(visual):
				state = State.IDLE
				return
			if is_instance_valid(source_ref):
				visual.global_position = source_ref.global_position
			strike_timer += delta
			if strike_timer <= strike_hold:
				var r = clampf(strike_timer / 0.1, 0.0, 1.0)
				visual.red_alpha = 0.65 * r
			else:
				var p = clampf((strike_timer - strike_hold) / strike_fade, 0.0, 1.0)
				visual.red_alpha = lerpf(0.65, 0.0, p)
			visual.line_alpha = 1.0
			visual.line_progress = 1.0
			visual.queue_redraw()
			if strike_timer >= strike_hold + strike_fade:
				visual.red_sectors.clear()
				disappear_timer = 0.0
				state = State.DISAPPEARING
		State.DISAPPEARING:
			if not is_instance_valid(visual):
				state = State.IDLE
				return
			if is_instance_valid(source_ref):
				visual.global_position = source_ref.global_position
			disappear_timer += delta
			var p = clampf(disappear_timer / disappear_time, 0.0, 1.0)
			visual.line_progress = 1.0 - p * p * (3.0 - 2.0 * p)
			visual.queue_redraw()
			if p >= 1.0:
				_kill_visual()
				state = State.IDLE

func _screen_radius() -> float:
	if tree_ref == null:
		return 1000.0
	var vp_size = tree_ref.root.get_viewport().get_visible_rect().size
	var zoom = 1.0
	var cam = tree_ref.root.get_camera_2d()
	if cam:
		zoom = maxf(cam.zoom.x, 0.001)
	return (vp_size.length() * 0.5 / zoom) * 1.1

func _start_strike() -> void :
	state = State.STRIKING
	strike_timer = 0.0
	visual.lit_sectors.clear()
	visual.red_sectors.clear()
	for i in range(base_sectors):
		visual.red_sectors.append(i)
	visual.red_alpha = 0.0
	visual.queue_redraw()
	_deal_damage()

func _deal_damage() -> void :
	if not is_instance_valid(source_ref) or tree_ref == null:
		return
	var center = source_ref.global_position
	var might_val = 1.0
	if "might" in source_ref:
		might_val = source_ref.might
	for enemy in tree_ref.get_nodes_in_group("Enemy"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var rel = enemy.global_position - center
		if rel.length() > active_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage * might_val)
		if strike_knockback > 0.0:
			var kb_dir = rel.normalized()
			if kb_dir == Vector2.ZERO:
				kb_dir = Vector2.UP
			if "knockback" in enemy:
				enemy.knockback = kb_dir * strike_knockback

func _kill_visual() -> void :
	if is_instance_valid(visual):
		visual.queue_free()
	visual = null

func reset():
	state = State.IDLE
	_kill_visual()
	source_ref = null
	tree_ref = null
