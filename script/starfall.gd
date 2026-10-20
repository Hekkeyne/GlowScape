extends Weapon
class_name Starfall

@export var sfx_shoot: AudioStream = null
@export var star_count: int = 1
@export var star_delay: float = 0.08
@export var textures: Array[Texture2D] = []
@export var spawn_spread: float = 8.0

var _last_angle: float = 0.0
var _player_ref: Node2D = null

func update(_delta: float) -> void:
	if not is_instance_valid(_player_ref):
		var tree = Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		_player_ref = tree.get_first_node_in_group("Player")
	if not is_instance_valid(_player_ref):
		return
	if "current_velocity" in _player_ref and _player_ref.current_velocity.length() > 10.0:
		_last_angle = _player_ref.current_velocity.normalized().angle()
	else:
		var sprite = _player_ref.get_node_or_null("Sprite2D")
		if sprite:
			_last_angle = sprite.rotation

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	_player_ref = source
	if "current_velocity" in source and source.current_velocity.length() > 10.0:
		_last_angle = source.current_velocity.normalized().angle()
	else:
		var sprite = source.get_node_or_null("Sprite2D")
		if sprite:
			_last_angle = sprite.rotation
	if sfx_shoot:
		_play_sfx(source, sfx_shoot, scene_tree)
	var tw = scene_tree.create_tween()
	for i in range(star_count):
		if i > 0:
			tw.tween_interval(star_delay)
		tw.tween_callback(_spawn_star.bind(source, scene_tree))

func _spawn_star(source: Node2D, scene_tree: SceneTree) -> void:
	if not is_instance_valid(self):
		return
	if not is_instance_valid(source):
		return
	var proj_scene = projectile_node
	if proj_scene == null:
		return
	var dir = Vector2.RIGHT.rotated(_last_angle)
	var star = proj_scene.instantiate()
	var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if offset.length_squared() > 0.001:
		offset = offset.normalized()
	else:
		offset = Vector2.RIGHT
	star.position = source.position + offset * randf_range(0.0, spawn_spread)
	star.direction = dir
	star.damage = damage
	star.speed = speed
	star.source = source
	star.weapon_ref = self
	if textures.size() > 0:
		star.bullet_texture = textures.pick_random()
	elif texture:
		star.bullet_texture = texture
	scene_tree.current_scene.add_child(star)

func _play_sfx(source: Node2D, stream: AudioStream, scene_tree: SceneTree) -> void:
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = -15
	player.pitch_scale = randf_range(0.8, 1.2)
	player.position = source.position
	scene_tree.current_scene.add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "speed" in upgrade:
		speed += upgrade.speed
	if "amount" in upgrade:
		star_count += upgrade.amount
	level += 1

func reset():
	_player_ref = null
