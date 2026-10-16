extends Node

@export var follow_speed: float = 6.0

var camera: Camera2D = null
var is_spectating: bool = false
var _targets: Array = []
var _current: int = -1
var _camera_was_top_level: bool = false
var _camera_physics_was: bool = true
var _camera_process_was: bool = true

func _ready() -> void:
	add_to_group("SpectatorManager")

func _exit_tree() -> void:
	stop_spectating()

func start_spectating() -> void:
	if is_spectating:
		return
	camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	is_spectating = true
	_camera_was_top_level = camera.top_level
	_camera_physics_was = camera.is_physics_processing()
	_camera_process_was = camera.is_processing()
	camera.top_level = true
	camera.set_physics_process(false)
	camera.set_process(false)
	_refresh_targets()
	if _targets.size() > 0:
		_current = 0
		camera.global_position = _targets[0].global_position

func stop_spectating() -> void:
	if not is_spectating:
		return
	is_spectating = false
	if camera != null and is_instance_valid(camera):
		camera.top_level = _camera_was_top_level
		camera.set_physics_process(_camera_physics_was)
		camera.set_process(_camera_process_was)

func _unhandled_input(event: InputEvent) -> void:
	if not is_spectating:
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		next_target()

func next_target() -> void:
	_refresh_targets()
	if _targets.is_empty():
		return
	_current = (_current + 1) % _targets.size()

func _refresh_targets() -> void:
	_targets.clear()
	var local_player = get_tree().get_first_node_in_group("player")
	if local_player != null and is_instance_valid(local_player) and not local_player.is_dead:
		_targets.append(local_player)
	for id in Net.peer_names:
		if id == multiplayer.get_unique_id():
			continue
		var n = get_tree().get_first_node_in_group("RemotePlayers_%d" % id)
		if n != null and is_instance_valid(n) and n.modulate.a > 0.5:
			_targets.append(n)

func _physics_process(delta: float) -> void:
	if not is_spectating or camera == null or not is_instance_valid(camera):
		return
	_refresh_targets()
	if _targets.is_empty():
		return
	if _current < 0 or _current >= _targets.size():
		_current = 0
	var t = _targets[_current]
	if not is_instance_valid(t):
		return
	camera.global_position = camera.global_position.lerp(t.global_position, clampf(delta * follow_speed, 0.0, 1.0))
