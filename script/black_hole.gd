class_name BlackHole
extends Node2D
@export var explosion_sound: AudioStream = null
var _explosion_audio: AudioStreamPlayer2D = null
@export var fly_speed: float = 900.0
@export var flight_scale: float = 0.3
@export var pull_radius: float = 220.0
@export var pull_radius_end: float = 420.0
@export var core_radius: float = 60.0
@export var pull_strength: float = 260.0
@export var pull_ramp: float = 2.0
@export var duration: float = 4.0
@export var grow_time: float = 0.2
@export var implode_time: float = 0.3
@export var spin_speed_end: float = 12.0
@export var dot_damage: float = 4.0
@export var explode_damage: float = 30.0
@export var explode_bonus: float = 4.0
@export var explode_radius: float = 260.0
@export var knock_strength: float = 500.0
@export var knock_time: float = 0.35
@export_range(0.1, 1.0, 0.05) var field_ratio: float = 1.0
@export var enable_missiles: bool = false
@export var missile_scene: PackedScene
@export var missile_damage: float = 20.0
@export var damage_per_missile: float = 25.0
@export_range(0, 4) var min_missiles: int = 2
@export_range(1, 10) var max_missiles: int = 6

var core_texture: Texture2D = null
var rim_texture: Texture2D = null
var swirl_texture: Texture2D = null
var field_texture: Texture2D = null
var missile_texture: Texture2D = null
var target_point: Vector2 = Vector2.ZERO
var source: Node2D = null
var phase: int = 0
var timer: float = 0.0
var spin: float = 0.0
var spin_speed: float = 4.0
var dot_tick: float = 0.0
var wave_r: float = 0.0
var current_pull: float = 0.0
var fly_from: Vector2 = Vector2.ZERO
var fly_t: float = 0.0
var fly_duration: float = 0.0
var fly_init: bool = false
var knocked: Array = []
var field: Sprite2D = null
var field_art_radius: float = 32.0
var implode_from_scale: float = 1.0
var damage_dealt: float = 0.0

@onready var core: Sprite2D = $Core
@onready var rim: Sprite2D = $Rim
@onready var swirl: Sprite2D = $Swirl
@onready var wave: Line2D = $Wave
@onready var sparks: Node2D = $Sparks

const PHASE_FLY = 0
const PHASE_GROW = 1
const PHASE_PULL = 2
const PHASE_IMPLODE = 3
const PHASE_BOOM = 4

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	z_index = 55
	field = get_node_or_null("Field")
	if core_texture:
		core.texture = core_texture
	if rim_texture:
		rim.texture = rim_texture
	if swirl_texture:
		swirl.texture = swirl_texture
	if field:
		field.visible = false
		if field_texture:
			field.texture = field_texture
		if field.texture:
			field_art_radius = field.texture.get_width() * 0.5 * field_ratio
		else:
			field_art_radius = 32.0 * field_ratio
	current_pull = pull_radius
	var fs = Vector2(flight_scale, flight_scale)
	core.scale = fs
	rim.scale = fs
	swirl.scale = fs
	wave.visible = false
	if explosion_sound != null:
		_explosion_audio = AudioStreamPlayer2D.new()
		_explosion_audio.stream = explosion_sound
		_explosion_audio.bus = "Master"
		add_child(_explosion_audio)

func _process(delta: float) -> void :
	timer += delta
	spin += delta * spin_speed
	swirl.rotation = spin
	rim.rotation = - spin * 0.6
	if field:
		field.rotation = - spin * 0.25
	match phase:
		PHASE_FLY:
			if not fly_init:
				fly_init = true
				fly_from = global_position
				fly_duration = maxf(target_point.distance_to(fly_from) / fly_speed, 0.15)
			fly_t += delta
			var t = clampf(fly_t / fly_duration, 0.0, 1.0)
			var p = t * t * (3.0 - 2.0 * t)
			global_position = fly_from.lerp(target_point, p)
			core.rotation = (target_point - fly_from).angle()
			if t >= 1.0:
				global_position = target_point
				phase = PHASE_GROW
				timer = 0.0
		PHASE_GROW:
			var t = clampf(timer / grow_time, 0.0, 1.0)
			var s = lerpf(flight_scale, 1.0, t)
			core.scale = Vector2(s, s)
			rim.scale = Vector2(s, s)
			swirl.scale = Vector2(s, s)
			if t >= 1.0:
				phase = PHASE_PULL
				timer = 0.0
				if field:
					field.visible = true
					_field_scale()
				_start_particles()
		PHASE_PULL:
			var prog = clampf(timer / duration, 0.0, 1.0)
			current_pull = lerpf(pull_radius, pull_radius_end, prog)
			spin_speed = lerpf(4.0, spin_speed_end, prog * prog)
			var s = clampf(current_pull / pull_radius, 1.0, 2.5)
			s *= 1.0 + sin(spin * 2.0) * 0.02
			core.scale = Vector2(s, s)
			rim.scale = Vector2(s, s)
			swirl.scale = Vector2(s, s)
			if field:
				_field_scale()
			_pull(delta, lerpf(1.0, pull_ramp, prog * prog))
			if timer >= duration:
				if enable_missiles:
					_spawn_missiles()
				implode_from_scale = s
				phase = PHASE_IMPLODE
				timer = 0.0
		PHASE_IMPLODE:
			var t = clampf(timer / implode_time, 0.0, 1.0)
			var e = t * t
			current_pull = lerpf(pull_radius_end, core_radius * 0.5, e)
			spin_speed = lerpf(spin_speed_end, 40.0, e)
			var s = maxf(lerpf(implode_from_scale, 0.05, e), 0.05)
			core.scale = Vector2(s, s)
			rim.scale = Vector2(s, s)
			swirl.scale = Vector2(s, s)
			if field:
				_field_scale()
			_pull(delta, lerpf(pull_ramp, 4.0, e))
			if t >= 1.0:
				_boom()
		PHASE_BOOM:
			wave_r += delta * 1400.0
			if is_instance_valid(wave):
				wave.points = _circle_points(wave_r)
				wave.modulate.a = clampf(1.0 - wave_r / (explode_radius * 2.2), 0.0, 1.0)
			_wave_knock(delta)
			if wave_r >= explode_radius * 2.2 and knocked.is_empty():
				queue_free()

func _start_particles() -> void :
	for child in sparks.get_children():
		if child is CPUParticles2D and not child.one_shot:
			child.emitting = true

func _field_scale() -> void :
	var s = current_pull / maxf(field_art_radius, 1.0)
	field.scale = Vector2(s, s)

func _pull(delta: float, strength_mult: float) -> void :
	dot_tick += delta
	var do_dot = dot_tick >= 0.5
	if do_dot:
		dot_tick = 0.0
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var to = global_position - node.global_position
		var dist = to.length()
		if dist > current_pull or dist < 1.0:
			continue
		var falloff = 1.0 - dist / current_pull
		node.global_position += to.normalized() * pull_strength * strength_mult * (0.25 + 0.75 * falloff) * delta
		if dist < core_radius and do_dot and dot_damage > 0.0:
			if node.has_method("take_damage"):
				var dealt = dot_damage * _might()
				node.take_damage(dealt)
				damage_dealt += dealt

func _spawn_missiles() -> void :
	var count = mini(max_missiles, min_missiles + int(damage_dealt / maxf(damage_per_missile, 1.0)))
	var shared_busy: Dictionary = {}
	for i in range(count):
		var missile: HoleMissile
		if missile_scene:
			missile = missile_scene.instantiate()
		else:
			missile = HoleMissile.new()
		missile.damage = missile_damage * _might()
		missile.texture = missile_texture
		missile.busy = shared_busy
		missile.launch_dir = Vector2.from_angle(randf() * TAU)
		missile.curve_spin = randf_range(3.0, 5.0) * (1.0 if randf() < 0.5 else -1.0)
		get_tree().current_scene.add_child(missile)
		missile.global_position = global_position

func _wave_knock(delta: float) -> void :
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var dist = node.global_position.distance_to(global_position)
		if dist <= wave_r and dist > wave_r - 60.0:
			var already = false
			for k in knocked:
				if k.n == node:
					already = true
					break
			if not already:
				var dir = Vector2.RIGHT
				if dist > 1.0:
					dir = (node.global_position - global_position).normalized()
				knocked.append({"n": node, "d": dir, "t": knock_time})
	for i in range(knocked.size() - 1, -1, -1):
		var k = knocked[i]
		if not is_instance_valid(k.n):
			knocked.remove_at(i)
			continue
		k.t -= delta
		if k.t <= 0.0:
			knocked.remove_at(i)
			continue
		k.n.global_position += k.d * knock_strength * (k.t / knock_time) * delta

func _boom() -> void :
	_explosion_audio.pitch_scale = randf_range(0.8, 1.2)
	_explosion_audio.volume_db = -15
	if _explosion_audio != null:
		_explosion_audio.play()
	phase = PHASE_BOOM
	timer = 0.0
	_try_shake(14.0, 0.5)
	for child in sparks.get_children():
		if child is CPUParticles2D:
			if child.one_shot:
				child.restart()
			else:
				child.emitting = false
	var inside = 0
	for node in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(node) and node is Node2D:
			if node.global_position.distance_to(global_position) <= core_radius * 1.5:
				inside += 1
	var total = (explode_damage + explode_bonus * inside) * _might()
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D:
			continue
		var dist = node.global_position.distance_to(global_position)
		if dist > explode_radius:
			continue
		var mult = 1.0
		if dist > core_radius:
			mult = lerpf(1.0, 0.5, (dist - core_radius) / maxf(explode_radius - core_radius, 1.0))
		if node.has_method("take_damage"):
			node.take_damage(total * mult)
	core.visible = false
	rim.visible = false
	swirl.visible = false
	if field:
		field.visible = false
	wave.visible = true
	wave.points = _circle_points(core_radius)
	wave_r = core_radius

func _might() -> float:
	if is_instance_valid(source) and "might" in source:
		return source.might
	return 1.0

func _try_shake(amp: float, time: float) -> void :
	if is_instance_valid(source) and source.has_method("screen_shake"):
		source.screen_shake(amp, time)
		return
	for node in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(node) and node.has_method("screen_shake"):
			node.screen_shake(amp, time)
			return

func _circle_points(r: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(32):
		pts.append(Vector2.from_angle(TAU * float(i) / 32.0) * r)
	return pts
