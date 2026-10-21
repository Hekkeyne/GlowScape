class_name HoleMissile
extends Node2D

var target: Node2D = null
var busy: Dictionary = {}
var damage: float = 20.0
var texture: Texture2D = null
var launch_dir: Vector2 = Vector2.UP
var curve_spin: float = 4.0
var curve_time: float = 0.45
var curve_speed: float = 480.0
var hook_time: float = 0.1
var dash_speed: float = 1400.0
var homing: float = 2.0
var hit_radius: float = 26.0
var max_life: float = 2.5

var phase: int = 0
var timer: float = 0.0
var dir: Vector2 = Vector2.UP
var sprite: Sprite2D = null

const PHASE_CURVE = 0
const PHASE_HOOK = 1
const PHASE_DASH = 2

func _ready() -> void :
	z_index = 56
	dir = launch_dir
	sprite = get_node_or_null("Sprite")
	if sprite == null and texture:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	if sprite and texture:
		sprite.texture = texture

func _process(delta: float) -> void :
	timer += delta
	if timer >= max_life:
		queue_free()
		return
	match phase:
		PHASE_CURVE:
			var t = clampf(timer / curve_time, 0.0, 1.0)
			dir = dir.rotated(curve_spin * delta)
			global_position += dir * lerpf(curve_speed, 60.0, t * t) * delta
			rotation = dir.angle()
			if t >= 1.0:
				phase = PHASE_HOOK
				timer = 0.0
				modulate = Color(3.0, 3.0, 3.0, 1.0)
				scale = Vector2(1.3, 1.3)
		PHASE_HOOK:
			if timer >= hook_time:
				phase = PHASE_DASH
				timer = 0.0
				modulate = Color(1.0, 1.0, 1.0, 1.0)
				scale = Vector2(1.0, 1.0)
				target = _acquire_target()
				if is_instance_valid(target):
					dir = (target.global_position - global_position).normalized()
		PHASE_DASH:
			if not is_instance_valid(target) or ("is_dying" in target and target.is_dying):
				target = _acquire_target()
			if is_instance_valid(target):
				var desired = (target.global_position - global_position).angle()
				var diff = wrapf(desired - dir.angle(), - PI, PI)
				dir = dir.rotated(signf(diff) * minf(absf(diff), homing * delta))
				if global_position.distance_to(target.global_position) < hit_radius:
					if target.has_method("take_damage"):
						target.take_damage(damage)
					queue_free()
					return
			global_position += dir * dash_speed * delta
			rotation = dir.angle()

func _acquire_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == null or not is_instance_valid(node) or not node is Node2D:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		if busy.has(node):
			continue
		var d = node.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = node
	if best != null:
		busy[best] = true
	return best
