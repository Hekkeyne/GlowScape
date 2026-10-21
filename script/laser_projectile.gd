extends Area2D
@export var sfx: Array[AudioStream] = []
var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 300
@export var damage: float = 2.5
@export var lifetime: float = 2.0
@export_range(0.1, 1.0, 0.05) var death_time: float = 0.25
@export_range(0.0, 30.0, 1.0) var death_spin: float = 10.0

@export_range(0.1, 1.0, 0.05) var fragment_speed_mult: float = 0.75
@export_range(0.1, 2.0, 0.05) var fragment_lifetime_mult: float = 0.5
@export_range(0.0, 10.0, 0.5) var fragment_turn_speed: float = 3.0
@export_range(0.0, 600.0, 25.0) var fragment_homing_radius: float = 250.0

var split_on_hit: bool = false
var is_fragment: bool = false
var projectile_scene: PackedScene = null
var has_split: bool = false
var bullet_texture: Texture2D = null:
	set(value):
		bullet_texture = value
		_apply_texture()
var _life_timer: float = 0.0
var _dying: bool = false
var _homing_target: Node2D = null
var _homing_timer: float = 0.0
var source
var _hit_this_frame: bool = false

func _apply_texture() -> void :
	var spr = find_child("Sprite2D", true, false)
	if spr and bullet_texture:
		spr.texture = bullet_texture

var net_id: int = 0

func _ready() -> void :
	add_to_group("Projectile")
	rotation = direction.angle()
	_apply_texture()

func _on_body_entered(body: Node2D) -> void :
	if _dying or _hit_this_frame:
		return
	if body.has_method("take_damage"):
		_deal_damage_to(body)
		_try_split()

func _on_area_entered(area: Area2D) -> void :
	if _dying or _hit_this_frame:
		return
	if area.get_parent().has_method("take_damage"):
		_deal_damage_to(area.get_parent())
		_try_split()

func _deal_damage_to(body: Node2D) -> void :
	_hit_this_frame = true
	if "might" in source:
		body.take_damage(damage * source.might)
	else:
		body.take_damage(damage)
	if has_node("AudioStreamPlayer2D"):
		$AudioStreamPlayer2D.stream = sfx.pick_random()
		$AudioStreamPlayer2D.pitch_scale = randf_range(0.7, 1.3)
		if is_fragment:
			$AudioStreamPlayer2D.volume_db = -10
		$AudioStreamPlayer2D.play()
	if "knockback" in body:
		body.knockback = direction * (75.0 if not is_fragment else 30.0)

func _try_split() -> void :
	if not split_on_hit or is_fragment or has_split:
		return
	has_split = true
	_split_projectiles.call_deferred()

func _split_projectiles() -> void :
	if projectile_scene == null:
		queue_free()
		return
	var fragment_count = 5
	var spread = deg_to_rad(35.0)
	for i in range(fragment_count):
		var t = float(i) / float(fragment_count - 1)
		var frag = projectile_scene.instantiate()
		frag.direction = direction.rotated(lerpf( - spread, spread, t))
		frag.damage = damage / 5.0
		frag.speed = speed * fragment_speed_mult
		frag.lifetime = lifetime * fragment_lifetime_mult
		frag.source = source
		frag.bullet_texture = bullet_texture
		frag.is_fragment = true
		frag.split_on_hit = false
		frag.projectile_scene = null
		get_tree().current_scene.add_child(frag)
		frag.global_position = global_position
	queue_free()

func _physics_process(delta: float) -> void :
	_hit_this_frame = false
	if _dying:
		global_position += direction * speed * 0.3 * delta
		rotation += death_spin * delta
		return
	if is_fragment and fragment_turn_speed > 0.0:
		_update_homing(delta)
	_life_timer += delta
	if _life_timer >= lifetime:
		_start_death()
		return
	var prev_pos = global_position
	global_position += direction * speed * delta
	rotation = direction.angle()
	_sweep_hit_enemies(prev_pos, global_position)

func _sweep_hit_enemies(prev: Vector2, cur: Vector2) -> void :
	if _dying or _hit_this_frame:
		return
	var seg = cur - prev
	if seg.length_squared() < 1.0:
		return
	var minx = minf(prev.x, cur.x) - 10.0
	var maxx = maxf(prev.x, cur.x) + 10.0
	var miny = minf(prev.y, cur.y) - 10.0
	var maxy = maxf(prev.y, cur.y) + 10.0
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var p = node.global_position
		if p.x < minx or p.x > maxx or p.y < miny or p.y > maxy:
			continue
		var closest = Geometry2D.get_closest_point_to_segment(p, prev, cur)
		if p.distance_squared_to(closest) <= 100.0:
			_deal_damage_to(node)
			_try_split()
			return

func _start_death() -> void :
	if _dying:
		return
	_dying = true
	set_deferred("monitoring", false)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, death_time)
	tw.tween_property(self, "scale", scale * 0.3, death_time)
	tw.finished.connect( func(): queue_free())

func _update_homing(delta: float) -> void :
	_homing_timer -= delta
	if _homing_timer <= 0.0:
		_homing_timer = 0.15
		_homing_target = _find_nearest_enemy()
	if is_instance_valid(_homing_target):
		var desired = (_homing_target.global_position - global_position).normalized()
		direction = direction.lerp(desired, clampf(fragment_turn_speed * delta, 0.0, 1.0)).normalized()

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d = fragment_homing_radius * fragment_homing_radius
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if "is_dying" in node and node.is_dying:
			continue
		var d = global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best
