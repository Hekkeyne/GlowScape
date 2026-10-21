extends Area2D
class_name NoteProjectile

@export var sfx: Array[AudioStream] = []
@export_range(0.0, 400.0, 10.0) var homing_radius: float = 180.0
@export_range(0.0, 10.0, 0.25) var homing_strength: float = 2.5

var direction: = Vector2.RIGHT
var speed: = 260.0
var damage: = 1.0
var knockback: = 40.0
var source

var _hit_enemies: Array = []
var lifetime: = 2.5
var _home_target: Node2D = null
var _home_timer: float = 0.0

const HOMING_INTERVAL: float = 0.15

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void :
	_process_homing(delta)
	global_position += direction * speed * delta
	rotation_degrees += 360.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _process_homing(delta: float) -> void :
	if homing_strength <= 0.0:
		return
	_home_timer -= delta
	if _home_timer <= 0.0 or not is_instance_valid(_home_target) or _hit_enemies.has(_home_target):
		_home_timer = HOMING_INTERVAL
		_home_target = _find_home_target()
	if not is_instance_valid(_home_target):
		return
	var desired = (_home_target.global_position - global_position).angle()
	var diff = wrapf(desired - direction.angle(), - PI, PI)
	direction = direction.rotated(signf(diff) * minf(absf(diff), homing_strength * delta))

func _find_home_target() -> Node2D:
	if homing_radius <= 0.0:
		return null
	var r2 = homing_radius * homing_radius
	var best: Node2D = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D:
			continue
		if _hit_enemies.has(node):
			continue
		var d = node.global_position.distance_squared_to(global_position)
		if d > r2:
			continue
		var to = (node.global_position - global_position).normalized()
		if to.dot(direction) < 0.25:
			continue
		if d < best_d:
			best_d = d
			best = node
	return best

func _on_body_entered(body: Node2D) -> void :
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("Enemy"):
		return
	_hit(body, body.global_position)

func _on_area_entered(area: Area2D) -> void :
	var target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("Enemy"):
		return
	var hit_position = area.global_position
	if target is Node2D:
		hit_position = target.global_position
	_hit(target, hit_position)

func _hit(target: Node, hit_position: Vector2) -> void :
	if _hit_enemies.has(target):
		return
	_hit_enemies.append(target)
	var final_damage = damage
	if source != null and "might" in source:
		final_damage *= source.might
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	if is_instance_valid(target) and target is Node2D and "knockback" in target:
		var kb = (target.global_position - global_position).normalized()
		if kb == Vector2.ZERO:
			kb = Vector2.RIGHT
		target.knockback = kb * knockback
	_play_sfx(hit_position)

func _play_sfx(pos: Vector2) -> void :
	if sfx.is_empty():
		return
	var player = get_node_or_null("AudioStreamPlayer2D")
	if player != null:
		player.stream = sfx.pick_random()
		player.pitch_scale = randf_range(0.8, 1.2)
		player.play()
	else:
		_spawn_audio(sfx.pick_random(), pos, -16.0)

func _spawn_audio(stream: AudioStream, pos: Vector2, volume_db: = -12.0) -> void :
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
	player.finished.connect( func(): player.queue_free())
