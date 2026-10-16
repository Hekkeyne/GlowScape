extends Node2D

@export var min_marker_distance: float = 80.0
@export var max_marker_distance: float = 250.0
@export var min_scale: float = 0.75
@export var max_scale: float = 1.0
@export var max_target_distance: float = 2000.0
@export var screen_margin: float = 50.0
@export var move_speed: float = 5.0

@onready var pointer: Sprite2D = $Pointer
@onready var skin: Sprite2D = $Skin

var target: Node2D = null
var _target_position: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if _target_position != Vector2.ZERO:
		global_position = global_position.lerp(_target_position, move_speed * delta)

func setup(p_target: Node2D, skin_texture: Texture2D) -> void:
	target = p_target
	if skin_texture and skin:
		skin.texture = skin_texture
	var player = get_tree().get_first_node_in_group("Player")
	if player and is_instance_valid(player):
		global_position = player.global_position
		_target_position = player.global_position

func update_marker() -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not is_instance_valid(player):
		return
	var target_world = target.global_position
	var player_world = player.global_position
	var canvas_transform = get_viewport().get_canvas_transform()
	var target_screen = canvas_transform * target_world
	var screen_size = get_viewport().get_visible_rect().size
	if _is_on_screen(target_screen, screen_size):
		visible = false
		return
	visible = true
	var to_target = target_world - player_world
	var dist_to_target = to_target.length()
	if dist_to_target < 1.0:
		visible = false
		return
	var dir = to_target / dist_to_target
	var t = clampf(dist_to_target / max_target_distance, 0.0, 1.0)
	var marker_dist = lerpf(min_marker_distance, max_marker_distance, t)
	_target_position = player_world + dir * marker_dist
	scale = Vector2.ONE * lerpf(max_scale, min_scale, t)
	pointer.rotation = dir.angle()
	skin.rotation = 0.0

func _is_on_screen(screen_pos: Vector2, screen_size: Vector2) -> bool:
	return screen_pos.x >= -screen_margin and screen_pos.x <= screen_size.x + screen_margin and screen_pos.y >= -screen_margin and screen_pos.y <= screen_size.y + screen_margin
