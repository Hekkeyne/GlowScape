extends Item
class_name Weapon

@export var damage: float
@export var cooldown: float
@export var speed: float
@export var projectile_node: PackedScene = preload("res://scene/laser_projectile.tscn")
@export var upgrades: Array[Upgrade]
@export var item_needed: Item
@export var evolution: Weapon
@export var before_evolution: Texture2D
@export var before_item_needed: Texture2D
@export var require_max_level_passive: bool = true

var slot

func activate(_source, _target, _scene_tree):
	pass

func is_upgradable() -> bool:
	if level <= upgrades.size():
		return true
	return false

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	_save_stats()
	var upgrade = upgrades[level - 1]
	damage += upgrade.damage
	cooldown += upgrade.cooldown
	level += 1

func max_level_reached():
	if upgrades.size() + 1 == level and upgrades.size() != 0:
		return true
	return false

func is_evolution_available() -> bool:
	if evolution == null or item_needed == null:
		return false
	if not max_level_reached():
		return false
	var partner = _find_partner_item()
	if partner == null:
		return false
	if item_needed is Weapon:
		return partner.max_level_reached()
	if require_max_level_passive and partner.has_method("max_level_reached"):
		return partner.max_level_reached()
	return true

func try_evolve() -> bool:
	if evolution == null or item_needed == null:
		return false
	if not max_level_reached():
		return false
	var partner = _find_partner_item()
	if partner == null:
		return false
	if item_needed is Weapon:
		if not partner.max_level_reached():
			return false
		if partner != self and partner.slot != null:
			partner.slot.item = null
	elif require_max_level_passive:
		if partner.has_method("max_level_reached") and not partner.max_level_reached():
			return false
	if slot != null:
		slot.item = evolution
		return true
	return false

func _find_partner_item():
	if slot == null or not slot.is_inside_tree():
		return null
	var player = slot.get_tree().get_first_node_in_group("Player")
	if player == null:
		return null
	for path in ["UI/weapons", "UI/PassiveItems"]:
		var container = player.get_node_or_null(path)
		if container == null:
			continue
		for s in container.get_children():
			if s == slot:
				continue
			if not ("item" in s) or s.item == null:
				continue
			if not is_instance_valid(s.item):
				continue
			if s.item.resource_path == item_needed.resource_path:
				return s.item
	return null

func update(_delta):
	pass

func reset():
	pass
