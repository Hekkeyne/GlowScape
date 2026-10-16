extends Node2D

@export var dash_range: float = 220.0
@export var telegraph_time: float = 0.25
@export var dash_cooldown_time: float = 2.0

const COLOR_READY := Color.WHITE
const COLOR_COOLDOWN := Color(0.75, 0.35, 1.0)
const COLOR_HP_HIGH := Color(0.2, 0.9, 0.3)
const COLOR_HP_LOW := Color(0.9, 0.15, 0.15)

var peer_id: int = 0
var _target_pos: Vector2 = Vector2.ZERO
var _target_rot: float = 0.0
var _last_vel: Vector2 = Vector2.ZERO
var _tp_pending: bool = false
var _tp_token: int = 0
var _cd_token: int = 0
var _ring_ready: bool = true
var _particle_color: Color = Color.WHITE
var _health_t: float = 1.0
var _is_dead_dummy: bool = false

@onready var target_point: Node2D = get_node_or_null("TargetPoint")
@onready var ring: Node2D = get_node_or_null("TargetPoint/ring")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var tp_particles: CPUParticles2D = get_node_or_null("start_teleport")
@onready var run_particles: CPUParticles2D = get_node_or_null("RunParticles")
@onready var sfx: Node = get_node_or_null("SFX")
@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var bar: TextureProgressBar = get_node_or_null("HealthBar")

func setup(id: int, pname: String, tex_path: String, pcolor: Color) -> void:
	peer_id = id
	add_to_group("RemotePlayers_%d" % id)
	add_to_group("RemotePlayer")
	if name_label:
		name_label.text = pname
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		if sprite:
			sprite.texture = tex
	_particle_color = pcolor
	if tp_particles != null:
		tp_particles.modulate = pcolor
	if run_particles != null:
		run_particles.modulate = pcolor
	_set_ring_ready(true)
	_update_bar()

func network_snap(pos: Vector2, vel: Vector2, health_t: float, rot: float = 0.0) -> void:
	if _is_dead_dummy:
		network_revive()
	_target_pos = pos
	_last_vel = vel
	_target_rot = rot
	_health_t = clampf(health_t, 0.0, 1.0)
	_update_bar()
	if run_particles:
		run_particles.emitting = vel.length_squared() > 4.0

func network_dash(target: Vector2) -> void:
	if _is_dead_dummy or _tp_pending:
		return
	if target_point:
		target_point.global_position = target
		target_point.visible = true
	if ring:
		ring.visible = true
	_set_ring_ready(false)
	_tp_pending = true
	if tp_particles != null:
		if tp_particles.one_shot:
			tp_particles.restart()
		else:
			tp_particles.emitting = true
	_tp_token += 1
	var token = _tp_token
	get_tree().create_timer(telegraph_time).timeout.connect(func():
		if token == _tp_token:
			_on_start_tp_timeout()
	, CONNECT_ONE_SHOT)

func network_dead() -> void:
	_tp_pending = false
	_tp_token += 1
	_cd_token += 1
	if target_point:
		target_point.visible = false
	if tp_particles != null:
		tp_particles.emitting = false
	if run_particles:
		run_particles.emitting = false
	_is_dead_dummy = true
	if sprite:
		sprite.modulate.a = 0.3

func network_revive() -> void:
	_is_dead_dummy = false
	if sprite:
		sprite.modulate.a = 1.0

func _on_start_tp_timeout() -> void:
	if not _tp_pending:
		return
	_tp_pending = false
	var dest = target_point.global_position if target_point else _target_pos
	_spawn_tp_particles(global_position)
	_spawn_tp_particles(dest)
	global_position = dest
	_target_pos = dest
	if tp_particles != null and not tp_particles.one_shot:
		tp_particles.emitting = false
	if sfx and sfx.has_method("play"):
		sfx.play()
	_cd_token += 1
	var ctoken = _cd_token
	get_tree().create_timer(dash_cooldown_time).timeout.connect(func():
		if ctoken == _cd_token:
			_set_ring_ready(true)
	, CONNECT_ONE_SHOT)

func _set_ring_ready(ready: bool) -> void:
	_ring_ready = ready
	if ring:
		ring.modulate = COLOR_READY if ready else COLOR_COOLDOWN

func _update_bar() -> void:
	if not bar:
		return
	bar.visible = _health_t < 0.999
	bar.value = _health_t * 100.0
	bar.tint_progress = COLOR_HP_LOW.lerp(COLOR_HP_HIGH, _health_t)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if _is_dead_dummy:
		return
	global_position = global_position.lerp(_target_pos, clampf(delta * 15.0, 0.0, 1.0))
	if sprite and is_instance_valid(sprite):
		sprite.rotation = lerp_angle(sprite.rotation, _target_rot, clampf(delta * 20.0, 0.0, 1.0))
		var target_squash := Vector2.ONE
		if _last_vel.length_squared() > 4.0:
			target_squash = Vector2(1.1, 0.9)
		sprite.scale = sprite.scale.lerp(target_squash, 15.0 * delta)
	if run_particles and is_instance_valid(run_particles) and sprite and is_instance_valid(sprite):
		run_particles.rotation = sprite.rotation
	if target_point and is_instance_valid(target_point) and not _tp_pending:
		if _last_vel.length_squared() > 4.0:
			target_point.global_position = global_position + _last_vel.normalized() * dash_range
			target_point.visible = _ring_ready
		else:
			target_point.visible = false

func _spawn_tp_particles(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 24
	p.one_shot = true
	p.emitting = true
	p.lifetime = 0.45
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = _particle_color
	p.global_position = pos
	get_tree().current_scene.add_child(p)
	p.finished.connect(p.queue_free)
