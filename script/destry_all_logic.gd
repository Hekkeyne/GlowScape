extends Weapon
class_name RouletteWeapon

@export_range(2, 16) var base_sectors: int = 8
@export_range(0.1, 1.5, 0.05) var appear_time: float = 0.4
@export_range(0.0, 2.0, 0.05) var start_hold: float = 0.45
@export_range(0.8, 5.0, 0.1) var spin_time: float = 1.8
@export_range(1, 6) var min_spins: int = 2
@export_range(2, 8) var max_spins: int = 4
@export_range(4.0, 30.0, 1.0) var highlight_fade: float = 10.0
@export_range(0.05, 1.0, 0.05) var lock_time: float = 0.35
@export_range(0.1, 1.0, 0.05) var lock_alpha: float = 0.6
@export_range(0.0, 2.0, 0.05) var strike_hold: float = 0.4
@export_range(0.1, 1.5, 0.05) var strike_fade: float = 0.35
@export_range(0.05, 0.5, 0.05) var highlight_alpha: float = 0.18
@export_range(0.0, 500.0, 25.0) var strike_knockback: float = 150.0
@export var step_sound: AudioStream = null
@export var destroy_sound: AudioStream = null
@export_range(0.0, 0.5, 0.01) var step_pitch_variance: float = 0.08

enum State{IDLE, APPEARING, SPINNING, LOCK, STRIKING, DISAPPEARING}
var state: int = State.IDLE
var appear_timer: float = 0.0
var spin_timer: float = 0.0
var lock_timer: float = 0.0
var strike_timer: float = 0.0
var disappear_timer: float = 0.0
var base_rotation: float = 0.0
var final_index: int = 0
var current_index: int = 0
var total_steps: int = 0
var active_radius: float = 1000.0
var sectors_current: int = 0

var visual: RouletteVisual = null
var source_ref: CharacterBody2D = null
var tree_ref: SceneTree = null
var _step_audio: AudioStreamPlayer2D = null

var _destroy_audio: AudioStreamPlayer2D = null
var _last_step_index: int = -1

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
	_free_audio()
	visual = RouletteVisual.new()
	visual.z_index = 100
	scene_tree.current_scene.add_child(visual)
	if step_sound != null:
		_step_audio = AudioStreamPlayer2D.new()
		_step_audio.stream = step_sound
		_step_audio.volume_db = -15
		scene_tree.current_scene.add_child(_step_audio)
	if destroy_sound != null:
		_destroy_audio = AudioStreamPlayer2D.new()
		_destroy_audio.stream = destroy_sound
		_destroy_audio.volume_db = -15
		scene_tree.current_scene.add_child(_destroy_audio)
	var sectors = _current_sectors()
	visual.sector_count = sectors
	active_radius = _screen_radius()
	visual.radius = active_radius
	visual.highlight_alpha = highlight_alpha
	visual.fade_speed = highlight_fade
	visual.fill_texture = texture
	visual.line_progress = 0.0
	visual.line_alpha = 1.0
	base_rotation = - PI / 2.0 - (TAU / sectors) / 2.0
	visual.base_rotation = base_rotation
	visual.highlight_index = -1
	visual.strike_index = -1
	visual.global_position = source_ref.global_position
	visual.queue_redraw()
	final_index = randi_range(0, sectors - 1)
	total_steps = sectors * randi_range(min_spins, max_spins) + final_index
	appear_timer = 0.0
	_last_step_index = -1
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
			var eased = 1.0 - pow(1.0 - p, 3.0)
			visual.line_progress = eased
			visual.queue_redraw()
			if p >= 1.0:
				spin_timer = 0.0
				_step_to(0)
				state = State.SPINNING
		State.SPINNING:
			if not is_instance_valid(visual) or not is_instance_valid(source_ref):
				_kill_visual()
				state = State.IDLE
				return
			visual.global_position = source_ref.global_position
			spin_timer += delta
			var p = clampf((spin_timer - start_hold) / spin_time, 0.0, 1.0)
			var eased = p * p * (3.0 - 2.0 * p)
			current_index = mini(int(eased * (total_steps + 1)), total_steps) % visual.sector_count
			_step_to(current_index)
			if p >= 1.0:
				state = State.LOCK
				lock_timer = 0.0
				_step_to(final_index)
		State.LOCK:
			if not is_instance_valid(visual) or not is_instance_valid(source_ref):
				_kill_visual()
				state = State.IDLE
				return
			visual.global_position = source_ref.global_position
			lock_timer += delta
			var q = clampf(lock_timer / (lock_time * 0.35), 0.0, 1.0)
			visual.highlight_alpha = lerpf(highlight_alpha, lock_alpha, q)
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
				visual.strike_alpha = 0.65 * r
			else:
				var p = clampf((strike_timer - strike_hold) / strike_fade, 0.0, 1.0)
				visual.strike_alpha = lerpf(0.65, 0.0, p)
			visual.line_alpha = 1.0
			visual.line_progress = 1.0
			visual.queue_redraw()
			if strike_timer >= strike_hold + strike_fade:
				visual.clear_highlight()
				visual.strike_index = -1
				disappear_timer = 0.0
				state = State.DISAPPEARING
		State.DISAPPEARING:
			if not is_instance_valid(visual):
				state = State.IDLE
				return
			if is_instance_valid(source_ref):
				visual.global_position = source_ref.global_position
			disappear_timer += delta
			var p = clampf(disappear_timer / appear_time, 0.0, 1.0)
			var eased = pow(1.0 - p, 3.0)
			visual.line_progress = eased
			visual.queue_redraw()
			if p >= 1.0:
				_kill_visual()
				state = State.IDLE

func _step_to(idx: int) -> void :
	if idx != _last_step_index:
		_play_step()
		_last_step_index = idx
	if is_instance_valid(visual):
		visual.move_highlight(idx)

func _play_step() -> void :
	if not is_instance_valid(_step_audio):
		return
	if step_pitch_variance > 0.0:
		_step_audio.pitch_scale = randf_range(1.0 - step_pitch_variance, 1.0 + step_pitch_variance)
	if is_instance_valid(source_ref):
		_step_audio.global_position = source_ref.global_position
	_step_audio.play()

func _play_destroy() -> void :
	if not is_instance_valid(_destroy_audio):
		return
	if is_instance_valid(source_ref):
		_destroy_audio.global_position = source_ref.global_position
	_destroy_audio.play()

func _free_audio() -> void :
	if is_instance_valid(_step_audio):
		_step_audio.queue_free()
	_step_audio = null
	if is_instance_valid(_destroy_audio):
		_destroy_audio.queue_free()
	_destroy_audio = null

func _current_sectors() -> int:
	if sectors_current < 2:
		sectors_current = base_sectors
	return sectors_current

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
	visual.clear_highlight()
	visual.strike_index = final_index
	visual.strike_alpha = 0.0
	visual.queue_redraw()
	_play_destroy()
	_deal_damage()

func _deal_damage() -> void :
	if not is_instance_valid(source_ref) or tree_ref == null:
		return
	var step = TAU / visual.sector_count
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
		var sector_idx = int(fposmod(rel.angle() - base_rotation, TAU) / step)
		if sector_idx != final_index:
			continue
		var final_damage = damage * might_val
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage)
		if strike_knockback > 0.0:
			var kb_dir = rel.normalized()
			if kb_dir == Vector2.ZERO:
				kb_dir = Vector2.RIGHT
			if "knockback" in enemy:
				enemy.knockback = kb_dir * strike_knockback

func _kill_visual() -> void :
	if is_instance_valid(visual):
		visual.queue_free()
	visual = null

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "speed" in upgrade:
		speed += upgrade.speed
	if "sectors" in upgrade:
		sectors_current = clampi(_current_sectors() + upgrade.sectors, 2, 32)
	level += 1

func reset():
	state = State.IDLE
	_kill_visual()
	_free_audio()
	_last_step_index = -1
	sectors_current = base_sectors
	source_ref = null
	tree_ref = null
