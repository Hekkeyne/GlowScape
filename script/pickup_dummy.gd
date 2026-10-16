extends Area2D

var target_pos: Vector2 = Vector2.ZERO
var _net_id: int = 0
var _type_path: String = ""
var _player_ref: CharacterBody2D = null
var _collected: bool = false
var _following: bool = false
var _speed: float = 210.0
var _add_speed: float = 1.0
var _sprite: Sprite2D = null

func _ready() -> void:
	_player_ref = get_tree().get_first_node_in_group("Player")
	_sprite = get_node_or_null("Sprite2D")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func update_from_snapshot(entry: Dictionary) -> void:
	_net_id = int(entry.get("id", 0))
	target_pos = entry.get("pos", Vector2.ZERO)
	var type_path = entry.get("type", "")
	if type_path != "" and type_path != _type_path:
		_type_path = type_path
		_load_type(type_path)
	var is_mega = entry.get("is_mega", false)
	var bonus_xp = entry.get("bonus_xp", 0.0)
	if is_mega or bonus_xp > 0:
		scale = Vector2(2.0, 2.0)
		if is_mega:
			modulate = Color.YELLOW

func _load_type(type_path: String) -> void:
	if _sprite == null:
		return
	if not ResourceLoader.exists(type_path):
		return
	var type_res = load(type_path)
	if type_res == null:
		return
	if "icon" in type_res and type_res.icon != null:
		_sprite.texture = type_res.icon

func follow(_target: CharacterBody2D) -> void:
	if _collected:
		return
	_following = true

func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _following and _player_ref and is_instance_valid(_player_ref) and not _player_ref.is_dead:
		var dir = (_player_ref.global_position - global_position).normalized()
		global_position += dir * _speed * _add_speed * delta
		_add_speed += 0.01
		if _sprite:
			_sprite.rotation = lerp_angle(_sprite.rotation, dir.angle() + PI / 2, 20.0 * delta)
	else:
		global_position = global_position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body == _player_ref and _player_ref and not _player_ref.is_dead:
		_collected = true
		if _net_id > 0:
			Net.send_pickup_collected(_net_id)
		queue_free()
