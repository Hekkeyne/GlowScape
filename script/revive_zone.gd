extends Node2D

@export var radius: float = 120.0
@export var revive_time: float = 3.0

var dead_player_id: int = 0
var _ring: ReviveRing = null
var _area: Area2D = null
var _progress: float = 0.0
var _active_count: int = 0
var _progress_acc: float = 0.0
const PROGRESS_SEND_INTERVAL: float = 0.05

func _ready() -> void :
	Net.revive_zone_progress_updated.connect(_on_progress_updated)
	Net.revive_zone_removed.connect(_on_zone_removed)
	_setup_area()
	_spawn_visual()

func _setup_area() -> void :
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1 | 2
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	_area.add_child(shape)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	add_child(_area)

func _spawn_visual() -> void :
	_ring = ReviveRing.new()
	_ring.radius = radius
	_ring.z_index = 50
	add_child(_ring)

func _is_player_body(body: Node2D) -> bool:
	if body.is_in_group("Player") or body.is_in_group("RemotePlayer"):
		return true
	var parent = body.get_parent()
	if parent and is_instance_valid(parent):
		if parent.is_in_group("Player") or parent.is_in_group("RemotePlayer"):
			return true
	return false

func _on_body_entered(body: Node2D) -> void :
	if _is_player_body(body):
		_active_count += 1

func _on_body_exited(body: Node2D) -> void :
	if _is_player_body(body):
		_active_count = max(0, _active_count - 1)
		if _active_count == 0 and _progress > 0.0:
			_reset_progress()
			Net.send_revive_progress(dead_player_id, 0.0)

func _on_progress_updated(id: int, progress: float) -> void :
	if id != dead_player_id:
		return
	_progress = progress
	if _ring:
		_ring.progress = progress

func _on_zone_removed(id: int) -> void :
	if id != dead_player_id:
		return
	set_physics_process(false)
	queue_free()

func _physics_process(delta: float) -> void :
	if _active_count == 0:
		if _progress > 0.0:
			_reset_progress()
		return
	_progress += delta
	_progress_acc += delta
	if _ring:
		_ring.progress = _progress / revive_time
	if _progress_acc >= PROGRESS_SEND_INTERVAL:
		_progress_acc = 0.0
		Net.send_revive_progress(dead_player_id, _progress / revive_time)
	if _progress >= revive_time:
		_complete_revive()

func _reset_progress() -> void :
	_progress = 0.0
	_progress_acc = 0.0
	if _ring:
		_ring.progress = 0.0

func _complete_revive() -> void :
	Net.send_revive_player(dead_player_id)
	Net.remove_revive_zone(dead_player_id)
	queue_free()

class ReviveRing extends Node2D:
	var radius: float = 120.0
	var progress: float = 0.0:
		set(value):
			progress = clampf(value, 0.0, 1.0)
			queue_redraw()
	var bg_color: Color = Color(0.2, 1.0, 0.4, 0.15)
	var ring_color: Color = Color(0.2, 1.0, 0.4, 0.7)
	var ring_width: float = 6.0
	func _draw() -> void :
		draw_circle(Vector2.ZERO, radius, bg_color)
		if progress > 0.001:
			var start_angle = - PI / 2.0
			var end_angle = start_angle + progress * TAU
			draw_arc(Vector2.ZERO, radius - ring_width / 2.0, start_angle, end_angle, 64, ring_color, ring_width, true)
