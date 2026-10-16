extends Node2D

@export var player: CharacterBody2D
@export var fallback_enemy_scene: PackedScene
@export var enemy_types: Array[Enemy]
@export var destructible: PackedScene
@export var start_distance: float = 900
@export var end_distance: float = 1500
var can_spawn: bool = true

@export_group("Endgame Buffs")
@export var endgame_health_bonus: float = 50.0
@export var endgame_damage_bonus: float = 10.0

@export_group("Pool Cycle")
@export_range(1, 10, 1) var minutes_per_type: int = 2
@export_range(0, 60, 1) var random_pool_minutes: int = 0
@export var enable_final_boss: bool = true
@export var boss_types: Array[Enemy] = []
@export var executioner_type: Enemy
@export var executioner_wipes_field: bool = true
@export var executioner_wipe_with_death: bool = false

@export_group("Adaptive Spawn")
@export_range(50, 500, 25) var initial_cap: int = 250
@export_range(200, 5000, 100) var hard_cap: int = 1000
@export_range(2, 30, 1) var calibration_seconds: int = 8
@export_range(0.5, 1.0, 0.05) var drop_ratio: float = 0.8
@export_range(0.5, 1.0, 0.05) var recover_ratio: float = 0.9
@export_range(0.5, 5.0, 0.5) var check_interval: float = 0.5
@export_range(1, 10, 1) var probe_step: int = 4
@export_range(5, 50, 5) var min_cap: int = 10
@export_range(1, 5, 1) var good_checks_needed: int = 2
@export_range(1, 5, 1) var bad_checks_needed: int = 2
@export_range(0.5, 1.0, 0.05) var cap_shrink: float = 0.85
@export_range(0.1, 1.0, 0.05) var fps_min_scale: float = 0.3
@export_range(0.0, 1.0, 0.05) var fps_smoothing: float = 0.9
@export_range(0.1, 5.0, 0.1) var baseline_decay: float = 0.8

@export_group("Spawn Queue")
@export_range(1, 10, 1) var spawn_per_frame: int = 3
@export_range(1, 20, 1) var burst_per_frame: int = 10
@export_range(50, 400, 25) var queue_max: int = 150
@export_range(5, 100, 5) var burst_threshold: int = 20

@export_group("Lag Culling")
@export var cull_enabled: bool = true
@export_range(0.3, 0.95, 0.05) var cull_ratio: float = 0.7
@export_range(0.5, 5.0, 0.5) var cull_interval: float = 1.0
@export_range(1, 40, 1) var cull_batch: int = 10
@export var cull_skip_elites: bool = true

@export_group("Gem Merging")
@export var gem_merge_enabled: bool = true
@export_range(0.3, 0.95, 0.05) var gem_merge_ratio: float = 0.8
@export_range(10, 200, 5) var gem_lag_cap: int = 60
@export_range(1, 60, 1) var gem_merge_batch: int = 20

var minute: int:
	set(value):
		minute = value
		if has_node("%minute"):
			%minute.text = str(value)
var second: int:
	set(value):
		second = value
		if second >= 60:
			second -= 60
			minute += 1
		if has_node("%second"):
			%second.text = str(second).lpad(2, '0')

var last_endgame_buff_minute: int = -1
var buff_stack: int = 0
var boss_index: int = 0
var executioner_spawned: bool = false
var executioner_alive: bool = false
var pool_minute: int = 0
var spawn_scale: float = 1.0

var _fps_smooth: float = 60.0
var baseline_fps: float = 60.0
var _recent_max: float = 60.0
var _calib_time: float = 0.0
var _calib_sum: float = 0.0
var _calibrated: bool = false
var _check_accum: float = 0.0
var _good_checks: int = 0
var _bad_checks: int = 0
var learned_cap: int = 250
var _cull_accum: float = 0.0
var _gem_merge_accum: float = 0.0
var _spawn_queue: Array = []

var _sec_accum: float = 0.0
var _spawns_this_sec: int = 0
var _spawns_prev_sec: int = 0
var _spawns_total: int = 0
var _skip_cap: int = 0
var _skip_max: int = 0
var _skip_exec: int = 0
var _skip_other: int = 0
var _culls_this_sec: int = 0
var _culls_prev_sec: int = 0
var _culls_total: int = 0
var _gems_merged_total: int = 0

func _ready() -> void:
	learned_cap = initial_cap

func _physics_process(delta: float) -> void:
	var fps = float(Engine.get_frames_per_second())
	_fps_smooth = lerpf(_fps_smooth, fps, 0.05)
	var budget = burst_per_frame if _spawn_queue.size() >= burst_threshold else spawn_per_frame
	while budget > 0 and not _spawn_queue.is_empty():
		spawn(_spawn_queue.pop_back())
		budget -= 1
	if _spawn_queue.size() > queue_max:
		_spawn_queue = _spawn_queue.slice(_spawn_queue.size() - queue_max)
	if not _calibrated:
		_calib_time += delta
		_calib_sum += fps * delta
		if _calib_time >= calibration_seconds:
			baseline_fps = maxf(_calib_sum / _calib_time, 1.0)
			_recent_max = baseline_fps
			_calibrated = true
	else:
		_check_accum += delta
		if _check_accum >= check_interval:
			_check_accum = 0.0
			_update_baseline()
			_adapt()
		if cull_enabled:
			_cull_accum += delta
			if _cull_accum >= cull_interval:
				_cull_accum = 0.0
				_try_cull()
		if gem_merge_enabled:
			_gem_merge_accum += delta
			if _gem_merge_accum >= check_interval:
				_gem_merge_accum = 0.0
				_try_merge_gems()
	spawn_scale = lerp(spawn_scale, _target_scale(), 1.0 - fps_smoothing)
	var live = get_tree().get_node_count_in_group("Enemy")
	can_spawn = live < learned_cap
	_sec_accum += delta
	if _sec_accum >= 1.0:
		_sec_accum -= 1.0
		_spawns_prev_sec = _spawns_this_sec
		_spawns_this_sec = 0
		_culls_prev_sec = _culls_this_sec
		_culls_this_sec = 0

func _update_baseline() -> void:
	_recent_max = maxf(_fps_smooth, _recent_max - baseline_decay * check_interval)
	baseline_fps = maxf(_recent_max, 1.0)

func _adapt() -> void:
	var ratio = _fps_smooth / baseline_fps
	var enemies = get_tree().get_node_count_in_group("Enemy")
	if ratio < drop_ratio:
		_good_checks = 0
		_bad_checks += 1
		if _bad_checks >= bad_checks_needed:
			var shrunk = int(learned_cap * cap_shrink)
			learned_cap = clampi(maxi(enemies, shrunk), min_cap, learned_cap)
			_bad_checks = 0
	elif ratio > recover_ratio:
		_bad_checks = 0
		_good_checks += 1
		if _good_checks >= good_checks_needed:
			var step = probe_step * (3 if ratio > 1.0 else 1)
			if enemies >= learned_cap - step:
				learned_cap = mini(learned_cap + step, hard_cap)
			_good_checks = 0
	else:
		_good_checks = 0
		_bad_checks = 0

func _target_scale() -> float:
	if not _calibrated:
		return 1.0
	var ratio = clampf(_fps_smooth / baseline_fps, 0.0, 1.5)
	if ratio >= drop_ratio:
		return 1.0
	var t = clampf(ratio / drop_ratio, 0.0, 1.0)
	return lerpf(fps_min_scale, 1.0, t)

func _try_cull() -> void:
	var ratio = _fps_smooth / baseline_fps
	if ratio >= cull_ratio:
		return
	if not is_instance_valid(player):
		return
	var enemies: Array = []
	var player_pos = player.global_position
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(node):
			continue
		var e = node as EnemyBase
		if e == null or e.is_dying:
			continue
		if cull_skip_elites and e.is_elite:
			continue
		if executioner_type != null and e.type == executioner_type:
			continue
		enemies.append(e)
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a, b): return a.global_position.distance_squared_to(player_pos) > b.global_position.distance_squared_to(player_pos))
	var n = mini(cull_batch, enemies.size())
	for i in range(n):
		_cull_enemy(enemies[i])

func _cull_enemy(e: EnemyBase) -> void:
	e.remove_from_group("Enemy")
	if e.collision_shape:
		e.collision_shape.set_deferred("disabled", true)
	e.set_physics_process(false)
	e.queue_free()
	_culls_this_sec += 1
	_culls_total += 1

func _try_merge_gems() -> void:
	var ratio = _fps_smooth / baseline_fps
	if ratio >= gem_merge_ratio:
		return
	var gems: Array = get_tree().get_nodes_in_group("Gem")
	if gems.size() <= gem_lag_cap:
		return
	var mega: Node = null
	for g in get_tree().get_nodes_in_group("MegaGem"):
		if is_instance_valid(g):
			mega = g
			break
	if mega == null:
		for g in gems:
			if not is_instance_valid(g) or not g.has_method("make_mega_gem"):
				continue
			if _gem_busy(g):
				continue
			mega = g
			mega.make_mega_gem()
			break
	if mega == null:
		return
	var excess = gems.size() - gem_lag_cap
	var budget = mini(excess, gem_merge_batch)
	var merged = 0
	for g in gems:
		if merged >= budget:
			break
		if g == mega or not is_instance_valid(g) or _gem_busy(g):
			continue
		if mega.has_method("add_bonus_xp") and "type" in g and g.type != null and "XP" in g.type:
			mega.add_bonus_xp(g.type.XP + float(g.get("bonus_xp")))
		g.remove_from_group("Gem")
		g.queue_free()
		merged += 1
	_gems_merged_total += merged

func _gem_busy(g: Node) -> bool:
	if g.get("is_projectile") or g.get("is_preparing"):
		return true
	if g.get("reserved_by") != null or g.get("attracted_by_enemy") != null:
		return true
	return false

func count_type(t: Enemy) -> int:
	var c := 0
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(node):
			continue
		var e = node as EnemyBase
		if e and not e.is_dying and e.type == t:
			c += 1
	return c

func _get_mix_minutes() -> int:
	return 1 if minutes_per_type >= 2 else 0

func _get_pool_end_minute() -> int:
	return enemy_types.size() * minutes_per_type - _get_mix_minutes()

func _get_transition_minutes() -> int:
	return minutes_per_type

func _get_pool_len() -> int:
	return _get_pool_end_minute() + _get_transition_minutes()

func _get_endgame_start_minute() -> int:
	return _get_pool_len()

func _get_cycle_len() -> int:
	return _get_pool_len() + maxi(random_pool_minutes, 0)

func spawn(pos: Vector2, elite: bool = false) -> void:
	if executioner_alive:
		_skip_exec += 1
		return
	if not can_spawn and not elite:
		_skip_cap += 1
		return
	var type = pick_type()
	if not type:
		_skip_other += 1
		return
	if type.max_count > 0 and count_type(type) >= type.max_count:
		_skip_max += 1
		return
	var scene = type.scene if type.scene else fallback_enemy_scene
	if not scene:
		_skip_other += 1
		return
	var enemy_instance = scene.instantiate()
	enemy_instance.type = type
	enemy_instance.position = pos
	enemy_instance.player_ref = player
	enemy_instance.is_elite = elite
	get_tree().current_scene.add_child(enemy_instance)
	_spawns_this_sec += 1
	_spawns_total += 1
	var stacks = _spawn_buff_stacks()
	for i in range(stacks):
		if enemy_instance.has_method("apply_endgame_buff"):
			enemy_instance.apply_endgame_buff(endgame_health_bonus, endgame_damage_bonus)

func _spawn_buff_stacks() -> int:
	if random_pool_minutes > 0:
		return buff_stack
	var endgame_start = _get_endgame_start_minute()
	if minute >= endgame_start:
		return minute - endgame_start + 1
	return 0

func pick_type() -> Enemy:
	if enemy_types.is_empty():
		return null
	var N = enemy_types.size()
	var L = maxi(minutes_per_type, 1)
	var t = _get_mix_minutes()
	var m = pool_minute if random_pool_minutes > 0 else minute
	var pool_end_min = _get_pool_end_minute()
	if m >= pool_end_min + _get_transition_minutes():
		for _try in range(4):
			var candidate = enemy_types[randi() % N]
			if candidate.max_count <= 0 or count_type(candidate) < candidate.max_count:
				return candidate
		return enemy_types[randi() % N]
	if m >= pool_end_min:
		var c1 = enemy_types[0]
		var c2 = enemy_types[randi() % N]
		if randf() < 0.5:
			if c1.max_count <= 0 or count_type(c1) < c1.max_count:
				return c1
			if c2.max_count <= 0 or count_type(c2) < c2.max_count:
				return c2
			return c1
		else:
			if c2.max_count <= 0 or count_type(c2) < c2.max_count:
				return c2
			if c1.max_count <= 0 or count_type(c1) < c1.max_count:
				return c1
			return c2
	var window = m / L
	var pos = m % L
	if window >= N - 1:
		return enemy_types[N - 1]
	if t > 0 and pos >= L - t:
		var a = enemy_types[window]
		var b = enemy_types[window + 1]
		if randf() < 0.5:
			if a.max_count <= 0 or count_type(a) < a.max_count:
				return a
			if b.max_count <= 0 or count_type(b) < b.max_count:
				return b
			return a
		else:
			if b.max_count <= 0 or count_type(b) < b.max_count:
				return b
			if a.max_count <= 0 or count_type(a) < a.max_count:
				return a
			return b
	return enemy_types[window]

func random_position() -> Vector2:
	return player.position + randf_range(start_distance, end_distance) * Vector2.RIGHT.rotated(randf_range(0, 2 * PI))

func amount(number: int = 1) -> void:
	var live = get_tree().get_node_count_in_group("Enemy")
	var head = learned_cap - live - _spawn_queue.size()
	var scaled = mini(int(round(float(number) * spawn_scale)), maxi(head, 0))
	for i in range(scaled):
		_spawn_queue.append(random_position())

func _on_timer_timeout() -> void:
	second += 1
	var progress: float = float(second % 60) / 60
	amount(int(2 + int(pow(progress, 2) * 15)) + minute * 3)
	if second == 0:
		_on_new_minute()

func _on_new_minute() -> void:
	pool_minute += 1
	if random_pool_minutes > 0:
		var cycle_len = _get_cycle_len()
		if pool_minute >= cycle_len:
			if not executioner_alive:
				_spawn_cycle_boss()
				buff_stack += 1
				_apply_buff_to_all()
				pool_minute = 0
	else:
		var endgame_start = _get_endgame_start_minute()
		if minute >= endgame_start and minute != last_endgame_buff_minute:
			last_endgame_buff_minute = minute
			_apply_buff_to_all()

func _spawn_cycle_boss() -> void:
	if enable_final_boss and boss_index < boss_types.size():
		var boss_type = boss_types[boss_index]
		boss_index += 1
		if boss_type:
			_spawn_special(boss_type)
		return
	if not executioner_spawned:
		executioner_spawned = true
		if executioner_type:
			_spawn_special(executioner_type)

func _spawn_special(type: Enemy) -> void:
	var scene = type.scene if type.scene else fallback_enemy_scene
	if not scene:
		return
	var instance = scene.instantiate()
	instance.type = type
	instance.position = random_position()
	instance.player_ref = player
	get_tree().current_scene.add_child(instance)
	for i in range(buff_stack):
		if instance.has_method("apply_endgame_buff"):
			instance.apply_endgame_buff(endgame_health_bonus, endgame_damage_bonus)
	if type == executioner_type:
		executioner_alive = true
		if executioner_wipes_field:
			_wipe_enemies(instance)
		instance.enemy_died.connect(_on_executioner_died, CONNECT_ONE_SHOT)

func _wipe_enemies(except: Node) -> void:
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == except:
			continue
		var e = node as EnemyBase
		if not e or e.is_dying:
			continue
		if executioner_wipe_with_death:
			e.ai = null
			e.die()
		else:
			e.remove_from_group("Enemy")
			if e.collision_shape:
				e.collision_shape.set_deferred("disabled", true)
			e.die()
	if is_instance_valid(except) and except.has_method("screen_shake"):
		except.screen_shake(18.0, 0.6)

func _on_executioner_died(_e: EnemyBase) -> void:
	executioner_alive = false
	buff_stack += 1
	_apply_buff_to_all()
	pool_minute = 0

func _apply_buff_to_all() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy.has_method("apply_endgame_buff"):
			enemy.apply_endgame_buff(endgame_health_bonus, endgame_damage_bonus)

func _on_pattern_timeout() -> void:
	var live = get_tree().get_node_count_in_group("Enemy")
	var head = learned_cap - live - _spawn_queue.size()
	var scaled = mini(int(round(50.0 * spawn_scale)), maxi(head, 0))
	for i in range(scaled):
		_spawn_queue.append(random_position())

func _on_elite_timeout() -> void:
	spawn(random_position(), true)

func _on_destructible_timeout() -> void:
	spawn_destructible(random_position())

func spawn_destructible(pos) -> void:
	var object = destructible.instantiate()
	object.position = pos
	get_tree().current_scene.add_child(object)
