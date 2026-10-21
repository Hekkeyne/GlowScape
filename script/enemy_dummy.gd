extends Node2D

var target_pos: Vector2 = Vector2.ZERO
var target_rot: float = 0.0
var target_scale: Vector2 = Vector2.ONE
var is_dying: bool = false

var _net_id: int = 0
var _type_path: String = ""
var _use_anim: bool = false
var _sprite: Sprite2D = null
var _anim: AnimatedSprite2D = null
var _separation: float = 0.0
var _last_update_time: float = 0.0

func _ready() -> void :
	add_to_group("Enemy")
	_sprite = get_node_or_null("Sprite2D")
	_anim = get_node_or_null("AnimatedSprite2D")
	if _sprite:
		_sprite.visible = false
	if _anim:
		_anim.visible = false
		_anim.stop()

func update_from_snapshot(entry: Dictionary) -> void :
	_net_id = int(entry.get("id", 0))
	target_pos = entry.get("pos", Vector2.ZERO)
	target_rot = entry.get("rot", 0.0)
	target_scale = entry.get("scale", Vector2.ONE)
	var flip: bool = entry.get("flip", false)
	var anim: String = entry.get("anim", "")
	var type_path: String = entry.get("type", "")
	if type_path != "" and type_path != _type_path:
		_load_type(type_path)
	if _use_anim and _anim != null:
		_anim.flip_h = flip
		if anim != "" and _anim.animation != anim:
			_anim.play(anim)
	elif _sprite != null:
		_sprite.flip_h = flip
	var dying: bool = entry.get("dying", false)
	if dying and not is_dying:
		is_dying = true
		_play_death()

func set_separation(value: float) -> void :
	_separation = value
	var player = get_tree().get_first_node_in_group("Player")
	if player and is_instance_valid(player):
		if "nearest_enemy_distance" in player:
			if _separation < player.nearest_enemy_distance:
				player.nearest_enemy = self
				player.nearest_enemy_distance = _separation

func take_damage(amount: float, is_crit: bool = false) -> void :
	if Net.is_host:
		return
	if _net_id <= 0 or is_dying:
		return
	Net.send_enemy_damage(_net_id, amount, is_crit)
	DamagePopup.spawn(global_position, amount, is_crit)

func _load_type(type_path: String) -> void :
	if not ResourceLoader.exists(type_path):
		return
	_type_path = type_path
	var type_res = load(type_path)
	if type_res == null:
		return
	var scene_res = type_res.scene
	if scene_res != null:
		var tmp = scene_res.instantiate()
		var src_anim = tmp.get_node_or_null("AnimatedSprite2D")
		var src_sprite = tmp.get_node_or_null("Sprite2D")
		if src_anim is AnimatedSprite2D and src_anim.sprite_frames != null:
			_use_anim = true
			if _anim != null:
				_anim.sprite_frames = src_anim.sprite_frames
				_anim.visible = true
			if _sprite != null:
				_sprite.visible = false
		elif src_sprite is Sprite2D and src_sprite.texture != null:
			_use_anim = false
			if _sprite != null:
				_sprite.texture = src_sprite.texture
				_sprite.visible = true
			if _anim != null:
				_anim.visible = false
		tmp.free()
	else:
		_use_anim = false
		if _sprite != null and type_res.texture != null:
			_sprite.texture = type_res.texture
			_sprite.visible = true
		if _anim != null:
			_anim.visible = false

func _physics_process(delta: float) -> void :
	if is_dying:
		return
	global_position = global_position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))
	rotation = lerp_angle(rotation, target_rot, clampf(delta * 12.0, 0.0, 1.0))
	scale = scale.lerp(target_scale, clampf(delta * 10.0, 0.0, 1.0))
	_last_update_time += delta
	if _last_update_time >= 0.1:
		_last_update_time = 0.0
		var player = get_tree().get_first_node_in_group("Player")
		if player and is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			set_separation(dist)

func _play_death() -> void :
	remove_from_group("Enemy")
	if _anim != null:
		_anim.stop()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
