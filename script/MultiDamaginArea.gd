extends Weapon
class_name DiscWeapon

@export_range(1, 12, 1) var amount: int = 2

var discs: Array = []
var _source = null
var _tree = null

func _init() -> void :
	speed = 220

func activate(source, _target, scene_tree) -> void :
	_source = source
	_tree = scene_tree
	_maintain()

func update(_delta: float) -> void :
	if _source == null or _tree == null:
		return
	_maintain()

func _maintain() -> void :
	for i in range(discs.size() - 1, -1, -1):
		if not is_instance_valid(discs[i]):
			discs.remove_at(i)
	for i in range(amount - discs.size()):
		_spawn_disc()

func _spawn_disc() -> void :
	if _tree == null or not is_instance_valid(_source):
		return
	var d = projectile_node.instantiate()
	d.damage = damage
	d.source = _source
	d.base_speed = speed
	d.current_max = speed
	var spr = d.find_child("Sprite2D", true, false)
	if spr:
		spr.texture = texture
	d.global_position = _source.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 80.0)
	discs.append(d)
	_tree.current_scene.call_deferred("add_child", d)

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "amount" in upgrade:
		amount += upgrade.amount
	if "speed" in upgrade:
		speed += upgrade.speed
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
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
	_source = null
	_tree = null
