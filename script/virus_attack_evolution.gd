extends Area2D
class_name ParasiteBug

@export var sfx: Array[AudioStream] = []
@export var jump_sfx: Array[AudioStream] = []

var damage := 1.0
var knockback := 40.0
var source

var current_target: Node2D = null
var is_small := false

var jumps_left := 3
var jump_radius := 260.0
var jump_speed := 520.0
var jump_delay := 0.25
var split_chance := 0.35
var small_bug_texture: Texture2D
var bug_scene: PackedScene

var _state := "JUMPING"
var _timer := 0.0
var _attach_offset := Vector2.ZERO
var _hit_enemies: Array = []
var lifetime := 6.0


func _ready() -> void:
	rotation = randf() * TAU

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if current_target != null and not is_instance_valid(current_target):
		current_target = null

	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()
		return

	if _state == "ATTACHED":
		# Сидим на враге, двигаемся вместе с ним.
		if is_instance_valid(current_target):
			global_position = current_target.global_position + _attach_offset

		_timer -= delta

		if _timer <= 0.0:
			if not _try_jump():
				queue_free()
		return

	# JUMPING
	if not is_instance_valid(current_target):
		if not _pick_next_target(null):
			queue_free()
		return

	var to_target = current_target.global_position - global_position
	var dist = to_target.length()

	if dist < 12.0:
		_arrive(current_target)
	else:
		global_position += (to_target / dist) * jump_speed * delta
		rotation += 10.0 * delta


func _on_body_entered(body: Node2D) -> void:
	if _state != "JUMPING":
		return

	if body == null or not is_instance_valid(body):
		return

	if not body.is_in_group("Enemy"):
		return

	_arrive(body)


func _on_area_entered(area: Area2D) -> void:
	if _state != "JUMPING":
		return

	var target = area.get_parent()

	if target == null or not is_instance_valid(target):
		return

	if not target.is_in_group("Enemy"):
		return

	_arrive(target)


func _arrive(enemy: Node) -> void:
	# Уже кусали этого врага — пролетаем сквозь.
	if _hit_enemies.has(enemy):
		return

	_hit_enemies.append(enemy)
	current_target = enemy
	_state = "ATTACHED"
	_attach_offset = Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, 2.0))
	_timer = jump_delay

	# Укус в момент касания — как у остальных снарядов.
	var final_damage = damage

	if source != null and "might" in source:
		final_damage *= source.might

	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage)

	if is_instance_valid(enemy) and enemy is Node2D and "knockback" in enemy:
		var kb = (enemy.global_position - global_position).normalized()

		if kb == Vector2.ZERO:
			kb = Vector2.UP

		enemy.knockback = kb * knockback

	_play_sfx(sfx, global_position, -12.0)

	if not is_small and split_chance > 0.0 and randf() < split_chance:
		_spawn_split()


func _try_jump() -> bool:
	if jumps_left <= 0:
		return false

	var exclude = current_target if is_instance_valid(current_target) else null

	if not _pick_next_target(exclude):
		return false

	jumps_left -= 1
	_state = "JUMPING"

	_play_sfx(jump_sfx, global_position, -16.0)

	return true


func _pick_next_target(exclude: Node) -> bool:
	var next_enemy = _find_nearest_enemy(exclude)

	if next_enemy == null:
		return false

	current_target = next_enemy
	return true


func _find_nearest_enemy(exclude: Node) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")

	var best: Node2D = null
	var best_distance = jump_radius

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		if enemy == exclude:
			continue

		if _hit_enemies.has(enemy):
			continue

		var dist = global_position.distance_to(enemy.global_position)

		if dist <= best_distance:
			best_distance = dist
			best = enemy

	return best


func _spawn_split() -> void:
	if bug_scene == null:
		return

	var scene = get_tree().current_scene

	if scene == null:
		return

	var exclude = current_target if is_instance_valid(current_target) else null
	var target_enemy = _find_nearest_enemy(exclude)

	if target_enemy == null:
		return

	var child = bug_scene.instantiate()

	child.is_small = true
	child.damage = max(1.0, damage * 0.5)
	child.source = source
	child.current_target = target_enemy
	child.jumps_left = 1
	child.jump_radius = jump_radius
	child.jump_speed = jump_speed
	child.jump_delay = jump_delay
	child.split_chance = 0.0
	child.scale = Vector2(0.6, 0.6)
	child.global_position = global_position

	var sprite = child.find_child("Sprite2D")
	if sprite != null and small_bug_texture != null:
		sprite.texture = small_bug_texture

	scene.call_deferred("add_child", child)


func _play_sfx(streams: Array[AudioStream], pos: Vector2, volume: float):
	if streams.is_empty():
		return

	var player = get_node_or_null("AudioStreamPlayer2D")

	if player != null:
		player.stream = streams.pick_random()
		player.pitch_scale = randf_range(0.8, 1.2)
		player.play()
	else:
		_spawn_audio(streams.pick_random(), pos, volume)


func _spawn_audio(stream: AudioStream, pos: Vector2, volume_db := -12.0) -> void:
	if stream == null:
		return

	var scene = get_tree().current_scene

	if scene == null:
		return

	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.8, 1.25)
	player.global_position = pos

	scene.add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
	
