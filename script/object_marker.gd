extends Node2D

@export var offset_from_target: float = 75
@export var min_marker_distance: float = 80.0
@export var max_marker_distance: float = 200.0
@export var min_scale: float = 0.75
@export var max_scale: float = 1
@export var max_target_distance: float = 1500.0
@export var screen_margin: float = 60.0
@export var move_speed: float = 5.0

@onready var pointer: Sprite2D = $Pointer
@onready var icon: Sprite2D = $Icon

var target: Node2D = null
var is_elite_marker: bool = false
var _target_position: Vector2 = Vector2.ZERO
var _current_icon: Texture2D = null
var _was_on_screen: bool = false

func _process(delta: float) -> void:
	if _target_position != Vector2.ZERO:
		global_position = global_position.lerp(_target_position, move_speed * delta)

func setup(p_target: Node2D, p_icon: Texture2D, p_is_elite: bool = false) -> void:
	target = p_target
	is_elite_marker = p_is_elite
	if p_icon and icon:
		icon.texture = p_icon
		_current_icon = p_icon
	var player = get_tree().get_first_node_in_group("Player")
	if player and is_instance_valid(player):
		global_position = player.global_position
		_target_position = player.global_position

func update_marker() -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not is_instance_valid(player) or player.is_dead:
		visible = false
		return
	var target_world = target.global_position
	var player_world = player.global_position
	var canvas_transform = get_viewport().get_canvas_transform()
	var target_screen = canvas_transform * target_world
	var screen_size = get_viewport().get_visible_rect().size
	var on_screen = _is_on_screen(target_screen, screen_size)
	if on_screen and is_elite_marker:
		visible = false
		return
	_update_icon()
	if on_screen:
		_update_direct_marker(target_world, player_world)
	else:
		_update_around_player_marker(target_world, player_world)
	visible = true
	_was_on_screen = on_screen

func _update_icon() -> void:
	if not icon or not is_instance_valid(target):
		return
	var new_icon = _get_target_icon()
	if new_icon != _current_icon:
		icon.texture = new_icon
		_current_icon = new_icon

func _get_target_icon() -> Texture2D:
	if not is_instance_valid(target):
		return null
	var sprite = target.get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = _find_sprite(target)
	if sprite and sprite.texture:
		return sprite.texture
	if "type" in target and target.type != null:
		if "icon" in target.type and target.type.icon != null:
			return target.type.icon
	return null

func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var found = _find_sprite(child)
		if found:
			return found
	return null

func _update_direct_marker(target_world: Vector2, player_world: Vector2) -> void:
	var to_target = target_world - player_world
	var dist = to_target.length()
	if dist < 1.0:
		visible = false
		return
	var dir = to_target / dist
	_target_position = target_world - dir * offset_from_target
	pointer.rotation = dir.angle()
	icon.rotation = 0.0
	scale = Vector2.ONE

func _update_around_player_marker(target_world: Vector2, player_world: Vector2) -> void:
	var to_target = target_world - player_world
	var dist = to_target.length()
	if dist < 1.0:
		visible = false
		return
	var dir = to_target / dist
	var t = clampf(dist / max_target_distance, 0.0, 1.0)
	var marker_dist = lerpf(min_marker_distance, max_marker_distance, t)
	_target_position = player_world + dir * marker_dist
	pointer.rotation = dir.angle()
	icon.rotation = 0.0
	scale = Vector2.ONE * lerpf(max_scale, min_scale, t)

func _is_on_screen(screen_pos: Vector2, screen_size: Vector2) -> bool:
	return screen_pos.x >= -screen_margin and screen_pos.x <= screen_size.x + screen_margin and screen_pos.y >= -screen_margin and screen_pos.y <= screen_size.y + screen_margin
