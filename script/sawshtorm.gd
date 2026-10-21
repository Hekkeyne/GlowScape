extends Weapon
class_name Sawstorm

@export_range(1, 12, 1) var amount: int = 3
@export var web_line_scene: PackedScene
@export_range(0.0, 3.0, 0.05) var web_damage_mult: float = 0.6
@export_range(0.05, 1.0, 0.05) var web_tick_interval: float = 0.2
@export_range(0.5, 10.0, 0.5) var web_line_lifetime: float = 3.0
@export_range(1, 32, 1) var web_max_lines: int = 12

var discs: Array = []
var _webs: Array = []
var _web_tick: float = 0.0
var _time: float = 0.0
var _source = null
var _tree = null

func activate(source, _target, scene_tree):
	_source = source
	_tree = scene_tree
	_maintain()

func update(delta):
	if _source == null or _tree == null:
		return
	_time += delta
	_maintain()
	_update_webs(delta)

func _maintain():
	for i in range(discs.size() - 1, -1, -1):
		if not is_instance_valid(discs[i]):
			discs.remove_at(i)
	for i in range(amount - discs.size()):
		_spawn_disc()

func _spawn_disc():
	if _tree == null or not is_instance_valid(_source):
		return
	var d = projectile_node.instantiate()
	d.damage = damage
	d.source = _source
	d.owner_weapon = self
	d.base_speed = speed
	d.current_max = speed
	d.global_position = _source.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 80.0)
	var spr = d.find_child("Sprite2D", true, false)
	if spr and texture:
		spr.texture = texture
	discs.append(d)
	_tree.current_scene.call_deferred("add_child", d)

func on_disc_hit(attacker: Node2D, _pos: Vector2) -> void :
	if _tree == null or not is_instance_valid(attacker):
		return
	if web_line_scene == null:
		return
	var nearest: Node2D = null
	var best_d: float = INF
	for d in discs:
		if d == attacker or not is_instance_valid(d):
			continue
		var dist = attacker.global_position.distance_squared_to(d.global_position)
		if dist < best_d:
			best_d = dist
			nearest = d
	if nearest == null or best_d < 1600.0:
		return
	_add_web(attacker.global_position, nearest.global_position)

func _add_web(a: Vector2, b: Vector2) -> void :
	if web_line_scene == null:
		return
	var root = web_line_scene.instantiate()
	var ln = _get_line(root)
	if ln == null:
		root.queue_free()
		return
	root.scale = Vector2.ONE
	root.rotation = 0.0
	_tree.current_scene.add_child(root)
	root.global_position = a
	ln.points = PackedVector2Array([ln.to_local(a), ln.to_local(b)])
	_webs.append({"root": root, "line": ln, "life": web_line_lifetime, "a": a, "b": b})
	while _webs.size() > web_max_lines:
		var old = _webs.pop_front()
		if is_instance_valid(old.root):
			old.root.queue_free()

func _get_line(root: Node) -> Line2D:
	if root is Line2D:
		return root
	for child in root.get_children():
		if child is Line2D:
			return child
		var nested = _get_line(child)
		if nested != null:
			return nested
	return null

func _update_webs(delta):
	for i in range(_webs.size() - 1, -1, -1):
		var w = _webs[i]
		if not is_instance_valid(w.root):
			_webs.remove_at(i)
			continue
		w.life -= delta
		if w.life <= 0.0:
			w.root.queue_free()
			_webs.remove_at(i)
			continue
		var t = clampf(w.life / web_line_lifetime, 0.0, 1.0)
		w.root.modulate.a = t * (0.75 + 0.25 * sin(_time * 10.0 + float(i)))
	_web_tick += delta
	if _web_tick >= web_tick_interval:
		var tick = _web_tick
		_web_tick = 0.0
		_web_damage(tick)

func _web_damage(tick: float) -> void :
	if web_damage_mult <= 0.0 or _webs.is_empty():
		return
	var dps = damage * web_damage_mult
	var might = 1.0
	if _source != null and "might" in _source:
		might = _source.might
	var enemies = _tree.get_nodes_in_group("Enemy")
	for w in _webs:
		var ln = w.line
		if not is_instance_valid(ln):
			continue
		var a: Vector2 = w.a
		var b: Vector2 = w.b
		var half = ln.width * 0.5
		for e in enemies:
			if not is_instance_valid(e) or not e is Node2D:
				continue
			if "is_dying" in e and e.is_dying:
				continue
			var p = e.global_position
			var closest = Geometry2D.get_closest_point_to_segment(p, a, b)
			var r = half + _enemy_radius(e)
			if p.distance_squared_to(closest) <= r * r:
				e.take_damage(dps * tick * might)

func _enemy_radius(e: Node2D) -> float:
	var r = e.get("hit_radius")
	if r == null:
		r = e.get("radius")
	if r == null:
		return 16.0
	return float(r)

func upgrade_item():
	if max_level_reached():
		slot.item = evolution
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "speed" in upgrade:
		speed += upgrade.speed
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "amount" in upgrade:
		amount += upgrade.amount
	level += 1
	for d in discs:
		if is_instance_valid(d):
			d.damage = damage
			d.set_base(speed)

func reset():
	for d in discs:
		if is_instance_valid(d):
			d.queue_free()
	discs.clear()
	for w in _webs:
		if is_instance_valid(w.root):
			w.root.queue_free()
	_webs.clear()
	_source = null
	_tree = null
