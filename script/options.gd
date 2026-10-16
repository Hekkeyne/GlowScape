extends HBoxContainer

@export var weapons: HBoxContainer
@export var passive_items: HBoxContainer
var OptionSlot = preload("res://scene/option_slot.tscn")
var DirectUpgradeSlotScene = preload("res://scene/direct_upgrade_slot.tscn")
@export var particles: CPUParticles2D
@export var panel: NinePatchRect
const weapon_path: String = "res://resourse/weapon/"
const passive_item_path: String = "res://resourse/Items/"
const direct_upgrade_path: String = "res://resourse/DirectUpgrades/"
var every_item
var every_weapon
var every_passive
var every_direct_upgrade: Array = []
var _popup_pool: Node2D = null
var random_upgrade_used: bool = false
var _pending_levels: int = 0
var _is_showing: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	particles.emitting = false
	panel.hide()
	get_all_item()
	every_direct_upgrade = dir_contents(direct_upgrade_path)
	_popup_pool = UpgradePopupPool.new()
	get_tree().current_scene.add_child.call_deferred(_popup_pool)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("random_upgrade"):
		trigger_random_upgrade()

func queue_level_up() -> void:
	_pending_levels += 1
	if not visible and not _is_showing:
		_show_next()

func _show_next() -> void:
	if _pending_levels <= 0:
		return
	_pending_levels -= 1
	_is_showing = true
	show_options()

func trigger_random_upgrade() -> void:
	if not random_upgrade_used:
		random_upgrade_used = true
	if visible:
		_pick_random_visible_slot()

func _pick_random_visible_slot() -> void:
	var slots: Array = []
	for child in get_children():
		if child is DirectUpgradeSlot:
			slots.append(child)
		elif child is TextureButton and "item" in child and child.item != null:
			slots.append(child)
	if slots.is_empty():
		close_option()
		return
	var slot = slots.pick_random()
	var player = get_tree().get_first_node_in_group("Player")
	if slot is DirectUpgradeSlot:
		if slot.upgrade:
			slot.upgrade.apply(player)
			if _popup_pool:
				_popup_pool.spawn(player.global_position, tr(slot.upgrade.title) + ": " + slot.upgrade.create_popup_text(), Color.GOLD)
		close_option()
		return
	var item: Item = slot.item
	var was_new: bool = ("is_new" in slot) and slot.is_new
	if not check_item(item):
		item.upgrade_item()
	elif item is PassiveItem:
		item.upgrade_item()
	if _popup_pool:
		var display_name = tr(item.title)
		if was_new:
			_popup_pool.spawn(player.global_position, display_name + " " + tr("NEW_ITEM_TEXT"), Color.GREEN)
		else:
			_popup_pool.spawn(player.global_position, display_name + " " + tr("LEVEL_OPTION_SLOT") % str(item.level), Color.WHITE)
	close_option()

func _is_item_in_array(item: Item, array: Array) -> bool:
	for other_item in array:
		if item == other_item:
			return true
		if item != null and other_item != null:
			if item.resource_path != "" and other_item.resource_path != "":
				if item.resource_path == other_item.resource_path:
					return true
			elif "title" in item and "title" in other_item:
				if item.title == other_item.title:
					return true
			elif item.get_script() != null and other_item.get_script() != null:
				if item.get_script() == other_item.get_script():
					return true
	return false

func get_available_resource_in(items) -> Array[Item]:
	var resources: Array[Item] = []
	for item in items.get_children():
		if item.item != null:
			resources.append(item.item)
	return resources

func add_option(item) -> int:
	if item is Item and item.is_upgradable():
		var option_slot = OptionSlot.instantiate()
		var equipped = get_available_resource_in(weapons)
		equipped.append_array(get_available_resource_in(passive_items))
		option_slot.is_new = not _is_item_in_array(item, equipped)
		option_slot.item = item
		add_child(option_slot)
		return 1
	return 0

func show_options():
	var equipped_all = get_available_resource_in(weapons)
	equipped_all.append_array(get_available_resource_in(passive_items))
	var upgradable_equipped = get_upgradable(equipped_all)
	var all_maxed = upgradable_equipped.is_empty()
	if random_upgrade_used:
		apply_random_upgrade(all_maxed)
		_is_showing = false
		if _pending_levels > 0:
			queue_level_up()
		return
	
	if all_maxed:
		show_direct_upgrades()
		return
	
	for slot in get_children():
		if slot is DirectUpgradeSlot or slot is TextureButton:
			slot.queue_free()
	var available = upgradable_equipped.duplicate()
	if slot_available(weapons):
		available.append_array(get_upgradable(every_weapon, equipped_all))
	if slot_available(passive_items):
		available.append_array(get_upgradable(every_passive, equipped_all))
	available.shuffle()
	var option_size = 0
	var chance = randf()
	var modifier: int = 1 if (chance < (1.0 - (1.0 / owner.luck))) else 0
	for i in range(3 + modifier):
		if available.size() > 0:
			option_size += add_option(available.pop_front())
	if option_size == 0:
		_is_showing = false
		if _pending_levels > 0:
			queue_level_up()
		return
	show()
	var rect: Rect2 = get_viewport().get_visible_rect()
	var center: Vector2 = rect.position + rect.size / 2.0
	var p_size: Vector2 = %Panel.size
	var start_pos = Vector2(center.x - p_size.x / 2.0, rect.end.y + p_size.y)
	var target_pos = center - p_size / 2.0
	%Panel.global_position = start_pos
	create_tween().tween_property(%Panel, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	particles.emitting = true
	panel.show()
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = true

func show_direct_upgrades():
	if every_direct_upgrade.is_empty():
		_is_showing = false
		if _pending_levels > 0:
			queue_level_up()
		return
	for slot in get_children():
		if slot is DirectUpgradeSlot or slot is TextureButton:
			slot.queue_free()
	var available = every_direct_upgrade.duplicate()
	available.shuffle()
	var option_size = 0
	var chance = randf()
	var modifier: int = 1 if (chance < (1.0 - (1.0 / owner.luck))) else 0
	for i in range(3 + modifier):
		if available.size() > 0:
			var upg = available.pop_front()
			var slot = DirectUpgradeSlotScene.instantiate()
			slot.setup(upg)
			add_child(slot)
			option_size += 1
	if option_size == 0:
		_is_showing = false
		if _pending_levels > 0:
			queue_level_up()
		return
	show()
	var rect: Rect2 = get_viewport().get_visible_rect()
	var center: Vector2 = rect.position + rect.size / 2.0
	var p_size: Vector2 = %Panel.size
	var start_pos = Vector2(center.x - p_size.x / 2.0, rect.end.y + p_size.y)
	var target_pos = center - p_size / 2.0
	%Panel.global_position = start_pos
	create_tween().tween_property(%Panel, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	particles.emitting = true
	panel.show()
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = true

func apply_random_upgrade(all_maxed: bool) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		return
	if all_maxed:
		if every_direct_upgrade.size() > 0:
			var upg = every_direct_upgrade.pick_random()
			upg.apply(player)
			if _popup_pool:
				_popup_pool.spawn(player.global_position, tr(upg.title) + ": " + upg.create_popup_text(), Color.GOLD)
		return
	var equipped_all = get_available_resource_in(weapons)
	equipped_all.append_array(get_available_resource_in(passive_items))
	var available = get_upgradable(equipped_all)
	if slot_available(weapons):
		available.append_array(get_upgradable(every_weapon, equipped_all))
	if slot_available(passive_items):
		available.append_array(get_upgradable(every_passive, equipped_all))
	if available.size() == 0:
		return
	var item: Item = available.pick_random()
	var was_new = not _is_item_in_array(item, equipped_all)
	if not check_item(item):
		item.upgrade_item()
	elif item is PassiveItem:
		item.upgrade_item()
	if _popup_pool:
		var display_name = tr(item.title)
		if was_new:
			_popup_pool.spawn(player.global_position, display_name + " " + tr("NEW_ITEM_TEXT"), Color.GREEN)
		else:
			_popup_pool.spawn(player.global_position, display_name + " " + tr("LEVEL_OPTION_SLOT") % str(item.level)+"/"+str(item.upgrades.size()+1), Color.WHITE)

func close_option():
	var rect: Rect2 = get_viewport().get_visible_rect()
	var center: Vector2 = rect.position + rect.size / 2.0
	var offscreen_pos = Vector2(center.x - %Panel.size.x / 2.0, rect.end.y + %Panel.size.y)
	await (create_tween().tween_property(%Panel, "global_position", offscreen_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)).finished
	hide()
	particles.emitting = false
	panel.hide()
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = false
	_is_showing = false
	if _pending_levels > 0:
		_show_next()

func dir_contents(path):
	var dir = DirAccess.open(path)
	var item_resources = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".remap", "").replace(".import", "")
				if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
					var item_resource = load(path + clean_name)
					if item_resource != null and not item_resources.has(item_resource):
						item_resources.append(item_resource)
			file_name = dir.get_next()
	return item_resources

func get_all_item():
	var item_resources = dir_contents(weapon_path)
	every_weapon = item_resources
	item_resources = dir_contents(passive_item_path)
	every_passive = item_resources
	every_item = every_weapon.duplicate()
	every_item.append_array(every_passive)

func slot_available(items):
	for item in items.get_children():
		if item.item == null:
			return true
	return false

func get_equipped_item():
	var equipped_items = get_available_resource_in(weapons)
	equipped_items.append_array(get_available_resource_in(passive_items))
	return get_upgradable(equipped_items)

func add_weapon(item):
	for slot in weapons.get_children():
		if slot.item == null:
			slot.item = item
			return

func add_passive(item):
	item.player_ref = self
	for slot in passive_items.get_children():
		if slot.item == null:
			slot.item = item
			return

func check_item(item) -> bool:
	var equipped_weapons = get_available_resource_in(weapons)
	var equipped_passives = get_available_resource_in(passive_items)
	if _is_item_in_array(item, equipped_weapons) or _is_item_in_array(item, equipped_passives):
		return false
	else:
		if item is Weapon:
			add_weapon(item)
		elif item is PassiveItem:
			add_passive(item)
		return true

func get_upgradable(items, flag = []):
	var array = []
	for item in items:
		if item.is_upgradable() and not _is_item_in_array(item, flag):
			array.append(item)
	return array

func get_available_upgrades() -> Array[Item]:
	var upgrades: Array[Item] = []
	for weapon: Weapon in get_available_resource_in(weapons):
		if weapon.is_upgradable():
			upgrades.append(weapon)
		if weapon.max_level_reached() and _is_item_in_array(weapon.item_needed, get_available_resource_in(passive_items)):
			upgrades.append(weapon)
	for passive_item: PassiveItem in get_available_resource_in(passive_items):
		if passive_item.is_upgradable():
			upgrades.append(passive_item)
	return upgrades

func _on_random_button_pressed() -> void:
	trigger_random_upgrade()
