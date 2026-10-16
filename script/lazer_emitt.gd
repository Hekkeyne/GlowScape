class_name LaserEmitters
extends Node2D

var weapon: LaserWeapon = null
var player: Node2D = null

var emitters: Array = []
var slot_offsets: PackedFloat32Array = PackedFloat32Array()
var slot_angles: PackedFloat32Array = PackedFloat32Array()
var side_angles: PackedFloat32Array = PackedFloat32Array()
var aim_angles: PackedFloat32Array = PackedFloat32Array()
var velocities: PackedVector2Array = PackedVector2Array()
var states: PackedInt32Array = PackedInt32Array()
var timers: PackedFloat32Array = PackedFloat32Array()
var recharge_max: PackedFloat32Array = PackedFloat32Array()
var phases: PackedFloat32Array = PackedFloat32Array()
var blink_phases: PackedFloat32Array = PackedFloat32Array()
var wait_beam: PackedByteArray = PackedByteArray()
var fire_timers: PackedFloat32Array = PackedFloat32Array()
var targets: Array = []
var beams: Array = []
var last_move_dir: Vector2 = Vector2.RIGHT
var rig_time: float = 0.0

const STATE_CROWN = 0
const STATE_OUT = 1
const STATE_HOLD = 2

func init_rig(p_weapon: LaserWeapon, p_player: Node2D) -> void:
	weapon = p_weapon
	player = p_player

func _process(delta: float) -> void:
	if not is_instance_valid(player) or weapon == null:
		queue_free()
		return
	rig_time += delta
	global_position = player.global_position
	_sync_count()
	_update_side(delta)
	var busy: Dictionary = {}
	for i in range(emitters.size()):
		if is_instance_valid(targets[i]):
			busy[targets[i]] = true
	for i in range(emitters.size()):
		var node = emitters[i]
		if not is_instance_valid(node):
			continue
		match states[i]:
			STATE_CROWN:
				timers[i] -= delta
				if timers[i] <= 0.0 and not _beams_alive(i):
					var t = _pick_target(busy)
					if t != null:
						targets[i] = t
						busy[t] = true
						states[i] = STATE_OUT
						aim_angles[i] = (t.global_position - node.global_position).angle()
						velocities[i] += Vector2.from_angle(slot_angles[i]) * weapon.launch_impulse
			STATE_OUT:
				if not is_instance_valid(targets[i]):
					_to_crown(i, 0.2)
				else:
					var diff = wrapf(aim_angles[i] - node.rotation, -PI, PI)
					node.rotation += signf(diff) * minf(absf(diff), weapon.aim_speed * delta)
					if absf(diff) < 0.1 and node.position.distance_to(_deploy_pos(i)) < 14.0:
						states[i] = STATE_HOLD
						timers[i] = weapon.freeze_time
			STATE_HOLD:
				if wait_beam[i] == 1:
					fire_timers[i] = maxf(0.0, fire_timers[i] - delta)
					if weapon.star_spin != 0.0:
						node.rotation += weapon.star_spin * delta
					if not _beams_alive(i):
						_to_crown(i, weapon.cooldown)
				else:
					if not is_instance_valid(targets[i]):
						_to_crown(i, 0.2)
					else:
						var diff = wrapf(aim_angles[i] - node.rotation, -PI, PI)
						node.rotation += signf(diff) * minf(absf(diff), weapon.aim_speed * delta)
						timers[i] -= delta
						if timers[i] <= 0.0:
							_fire(i)
		_move(i, delta)
		_apply_visual(i, delta)

func _update_side(delta: float) -> void:
	var v: Vector2 = Vector2.ZERO
	if player is CharacterBody2D:
		v = (player as CharacterBody2D).velocity
	if v.length_squared() > 400.0:
		last_move_dir = v.normalized()
	var behind = _behind_angle()
	for i in range(emitters.size()):
		if states[i] != STATE_CROWN:
			slot_angles[i] = side_angles[i] + slot_offsets[i]
			continue
		var diff = wrapf(behind - side_angles[i], -PI, PI)
		side_angles[i] += signf(diff) * minf(absf(diff), weapon.side_swing_speed * delta)
		slot_angles[i] = side_angles[i] + slot_offsets[i]

func _behind_angle() -> float:
	return (last_move_dir * -1.0).angle()

func _sync_count() -> void:
	var n = weapon.laser_count
	while emitters.size() < n:
		_add_emitter()
	while emitters.size() > n:
		_remove_emitter(emitters.size() - 1)

func _add_emitter() -> void:
	var node: Node2D
	if weapon.emitter_scene:
		node = weapon.emitter_scene.instantiate()
	else:
		node = Node2D.new()
		var s = Sprite2D.new()
		s.name = "Sprite"
		if weapon.emitter_texture:
			s.texture = weapon.emitter_texture
		node.add_child(s)
	node.z_index = 40
	add_child(node)
	emitters.append(node)
	slot_offsets.append(0.0)
	slot_angles.append(_behind_angle())
	side_angles.append(_behind_angle())
	aim_angles.append(0.0)
	velocities.append(Vector2.ZERO)
	states.append(STATE_CROWN)
	timers.append(randf_range(0.0, 0.3))
	recharge_max.append(0.3)
	phases.append(randf() * TAU)
	blink_phases.append(randf() * TAU)
	wait_beam.append(0)
	fire_timers.append(0.0)
	targets.append(null)
	beams.append([])
	_recompute_offsets()
	node.position = _slot_pos(emitters.size() - 1)

func _remove_emitter(i: int) -> void:
	for b in beams[i]:
		if is_instance_valid(b):
			b.queue_free()
	if is_instance_valid(emitters[i]):
		emitters[i].queue_free()
	emitters.remove_at(i)
	slot_offsets.remove_at(i)
	slot_angles.remove_at(i)
	side_angles.remove_at(i)
	aim_angles.remove_at(i)
	velocities.remove_at(i)
	states.remove_at(i)
	timers.remove_at(i)
	recharge_max.remove_at(i)
	phases.remove_at(i)
	blink_phases.remove_at(i)
	wait_beam.remove_at(i)
	fire_timers.remove_at(i)
	targets.remove_at(i)
	beams.remove_at(i)
	_recompute_offsets()

func _recompute_offsets() -> void:
	var n = emitters.size()
	slot_offsets.resize(n)
	var half = weapon.crown_span * 0.5
	if n % 2 == 1:
		var P = (n - 1) / 2
		for i in range(n):
			if i == 0:
				slot_offsets[i] = 0.0
			elif i % 2 == 1:
				slot_offsets[i] = half * float((i + 1) / 2) / float(maxi(P, 1))
			else:
				slot_offsets[i] = -half * float(i / 2) / float(maxi(P, 1))
	else:
		var P = n / 2
		for i in range(n):
			var p = i / 2 + 1
			var mag = half * float(2 * p - 1) / float(maxi(2 * P - 1, 1))
			slot_offsets[i] = mag if i % 2 == 0 else -mag

func _slot_pos(i: int) -> Vector2:
	var base = Vector2.from_angle(slot_angles[i]) * weapon.crown_radius
	base.y += sin(rig_time * weapon.bob_freq + phases[i]) * weapon.bob_amp
	base.x += sin(rig_time * weapon.bob_freq * 0.6 + phases[i] * 1.7) * weapon.bob_amp * 0.4
	return base

func _deploy_pos(i: int) -> Vector2:
	return Vector2.from_angle(slot_angles[i]) * weapon.deploy_radius

func _to_crown(i: int, t: float) -> void:
	states[i] = STATE_CROWN
	timers[i] = t
	recharge_max[i] = t
	targets[i] = null
	wait_beam[i] = 0

func _move(i: int, delta: float) -> void:
	var node = emitters[i]
	if states[i] == STATE_HOLD and wait_beam[i] == 1:
		velocities[i] *= exp(-weapon.spring_damping * delta)
		node.position += velocities[i] * delta
		return
	var target_local: Vector2
	var stiffness: float
	if states[i] == STATE_CROWN:
		target_local = _slot_pos(i)
		stiffness = weapon.crown_stiffness
	else:
		target_local = _deploy_pos(i)
		stiffness = weapon.dive_stiffness
	velocities[i] += (target_local - node.position) * stiffness * delta
	velocities[i] *= exp(-weapon.spring_damping * delta)
	node.position += velocities[i] * delta

func _pick_target(busy: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var r2 = _attack_radius() * _attack_radius()
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D or busy.has(node):
			continue
		var d = node.global_position.distance_squared_to(global_position)
		if d > r2:
			continue
		if d < best_d:
			best_d = d
			best = node
	return best

func _attack_radius() -> float:
	if is_instance_valid(player) and "area" in player:
		return player.area
	return 0

func _beams_alive(i: int) -> bool:
	for b in beams[i]:
		if is_instance_valid(b):
			return true
	return false

func _fire(i: int) -> void:
	var base_dir = Vector2.from_angle(aim_angles[i])
	emitters[i].rotation = aim_angles[i]
	var shared_hits: Dictionary = {}
	var new_beams: Array = []
	var dmg = weapon.damage
	if is_instance_valid(player) and "might" in player:
		dmg *= player.might
	for s in range(weapon.star_count):
		var beam: LaserBeam
		if weapon.beam_scene:
			beam = weapon.beam_scene.instantiate()
		else:
			beam = LaserBeam.new()
		var dir = base_dir.rotated(TAU * float(s) / float(weapon.star_count))
		beam.setup(emitters[i], player, dir, weapon.max_reflections, dmg, weapon.beam_duration, weapon.grow_time)
		beam.spin_speed = weapon.star_spin
		beam.rehit_interval = weapon.rehit_interval
		beam.hit_enemies = shared_hits
		get_tree().current_scene.add_child(beam)
		new_beams.append(beam)
	beams[i] = new_beams
	wait_beam[i] = 1
	fire_timers[i] = weapon.beam_duration
	velocities[i] += -base_dir * weapon.recoil_force

func _apply_visual(i: int, delta: float) -> void:
	var node = emitters[i]
	if not is_instance_valid(node):
		return
	if states[i] == STATE_CROWN:
		var desired = slot_angles[i] + sin(rig_time * 3.0 + phases[i]) * 0.06
		node.rotation = lerp_angle(node.rotation, desired, 10.0 * delta)
		var progress: float = 1.0
		if recharge_max[i] > 0.0:
			progress = clampf(1.0 - timers[i] / recharge_max[i], 0.0, 1.0)
		blink_phases[i] += delta * lerpf(6.0, 16.0, progress)
		var base_a = lerpf(0.1, 1.0, progress)
		var amp = 0.25 * sin(progress * PI)
		node.modulate = Color(1.0, 1.0, 1.0, clampf(base_a + sin(blink_phases[i]) * amp, 0.0, 1.0))
	elif states[i] == STATE_OUT:
		node.modulate = Color(0.04, 0.9, 0.4, 1.0)
	elif wait_beam[i] == 1:
		var life_t = clampf(fire_timers[i] / weapon.beam_duration, 0.0, 1.0)
		node.modulate = Color(1.4, 1.4, 1.4, lerpf(0.1, 1.0, life_t))
	else:
		var fp = clampf(1.0 - timers[i] / weapon.freeze_time, 0.0, 1.0)
		node.modulate = Color(0.04, 0.9, 0.4, 1.0).lerp(Color(2.0, 2.0, 2.0), fp)
	var stretch = clampf(velocities[i].length() / 2500.0, 0.0, 0.15)
	node.scale = Vector2(1.0 + stretch, 1.0 - stretch)
