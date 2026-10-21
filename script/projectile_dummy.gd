extends Node2D

var target_pos: Vector2 = Vector2.ZERO
var target_rot: float = 0.0
var _net_id: int = 0
var _sprite: Sprite2D = null
var _tex_path: String = ""

func _ready() -> void :
	_sprite = Sprite2D.new()
	add_child(_sprite)

func update_from_snapshot(entry: Dictionary) -> void :
	_net_id = int(entry.get("id", 0))
	target_pos = entry.get("pos", Vector2.ZERO)
	target_rot = entry.get("rot", 0.0)
	var tex_path = str(entry.get("tex", ""))
	if tex_path != "" and tex_path != _tex_path:
		_tex_path = tex_path
		if ResourceLoader.exists(tex_path):
			_sprite.texture = load(tex_path)

func _physics_process(delta: float) -> void :
	global_position = global_position.lerp(target_pos, clampf(delta * 20.0, 0.0, 1.0))
	rotation = lerp_angle(rotation, target_rot, clampf(delta * 20.0, 0.0, 1.0))
