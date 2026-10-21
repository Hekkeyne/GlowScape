extends NinePatchRect

var mchip_popup_node = preload("res://scene/mchip_add_label.tscn")
@onready var wheel: TextureRect = $WheelSprite
@onready var options: HBoxContainer = %Options
@onready var reward: Control = $WheelSprite / Reward
@onready var open_button: TextureButton = $Open
@onready var open_label: Label = $Open / Button_label
@onready var close_button: TextureButton = $Close
var mchip: Microchips = load("res://resourse/pickups/microchips.tres")
var is_spinning: bool = false
const SECTOR_ANGLE: float = 45.0
var remaining_spins: int = 0

func _ready() -> void :
	randomize()
	hide()
	for slot in reward.get_children():
		slot.pivot_offset = slot.size / 2.0

func open_check():
	var upgrades = options.get_available_upgrades()
	if upgrades.size() == 0:
		apply_upgrade()
		var popup = mchip_popup_node.instantiate()
		popup.text = "+" + tr("TR_CHIPS") % str(mchip.microchips)
		popup.position = owner.global_position + Vector2.ZERO
		popup.set("theme_override_colors/font_color", Color.YELLOW)
		get_tree().current_scene.add_child(popup)
		if not multiplayer.has_multiplayer_peer():
			get_tree().paused = false
		return
	open()

func open():
	var upgrades = options.get_available_upgrades()
	$Win_Label.text = ""
	wheel.pivot_offset = wheel.size / 2
	show()
	var rect: Rect2 = get_viewport().get_visible_rect()
	var p_size: Vector2 = size
	var target_pos: Vector2
	var start_pos: Vector2
	if multiplayer.has_multiplayer_peer():
		target_pos = Vector2(rect.size.x - p_size.x - 20.0, rect.size.y / 2.0 - p_size.y / 2.0)
		start_pos = Vector2(rect.size.x + p_size.x, target_pos.y)
	else:
		var center: Vector2 = rect.position + rect.size / 2.0
		start_pos = Vector2(center.x - p_size.x / 2.0, rect.end.y + p_size.y)
		target_pos = center - p_size / 2.0
		if not multiplayer.has_multiplayer_peer():
			get_tree().paused = true
	global_position = start_pos
	var weight = [5.0, 2.0, 1.0]
	var chance = randf()
	if chance < get_weighted_chance(weight, 0):
		remaining_spins = 1
	elif chance < get_weighted_chance(weight, 1):
		remaining_spins = 2
	else:
		remaining_spins = 3
	update_button_text()
	open_button.show()
	close_button.hide()
	generate_all_rewards()

	var tween = create_tween().tween_property(self, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	if multiplayer.has_multiplayer_peer():
		_auto_start_spin()

func get_weighted_chance(weight: Array, index: int) -> float:
	var modified_weight = []
	var sum = 0.0
	for i in range(weight.size()):
		if i == 0:
			modified_weight.append(weight[i])
			sum += weight[i]
		else:
			var luck_multiplier = 1.0
			if owner and owner.get("luck") != null:
				luck_multiplier = owner.luck
			modified_weight.append(weight[i] * luck_multiplier)
			sum += weight[i] * luck_multiplier
	var cumulative = 0.0
	for i in range(index + 1):
		cumulative += modified_weight[i]
	return float(cumulative) / sum

func generate_all_rewards() -> void :
	clear_reward()
	for i in range(8):
		var slot = reward.get_child(i)
		slot.pivot_offset = slot.size / 2.0
		var upgrades = options.get_available_upgrades()
		if upgrades.size() == 0:
			slot.texture = get_microchips_texture()
		else:
			var selected_upgrade: Item = upgrades.pick_random()
			if selected_upgrade is Weapon and selected_upgrade.max_level_reached():
				slot.texture = selected_upgrade.evolution.icon
			else:
				slot.texture = selected_upgrade.icon
			slot.set_meta("upgrade_data", selected_upgrade)

func update_button_text() -> void :
	if multiplayer.has_multiplayer_peer():
		if open_label:
			open_label.text = "(%s)" % str(remaining_spins)
		else:
			open_button.text = "(%s)" % str(remaining_spins)
	else:
		if open_label:
			open_label.text = tr("SPIN_BUTTON") % str(remaining_spins)
		else:
			open_button.text = tr("SPIN_BUTTON") % str(remaining_spins)

func _auto_start_spin() -> void :
	await get_tree().create_timer(0.3).timeout
	_do_spin()

func _on_open_pressed() -> void :
	if is_spinning or remaining_spins <= 0:
		return
	_do_spin()

func _do_spin() -> void :
	if is_spinning or remaining_spins <= 0:
		return
	is_spinning = true
	open_button.disabled = true
	await fade_out_all_slots()
	var winning_sector = randi_range(0, 7)
	var start_offset = randi_range(0, 7)
	var full_rotations = randi_range(2, 3)
	var distance = (winning_sector - start_offset + 8) % 8
	var total_steps = full_rotations * 8 + distance + 1
	for i in range(total_steps):
		var current_sector = (i + start_offset) % 8
		highlight_sector(current_sector)
		var progress = float(i) / float(total_steps - 1)
		var delay = calculate_eased_delay(progress)
		await get_tree().create_timer(delay).timeout
	is_spinning = false
	remaining_spins -= 1
	await blink_winner(winning_sector)
	process_wheel_result(winning_sector)

	if multiplayer.has_multiplayer_peer():
		await get_tree().create_timer(3.0).timeout
		$Win_Label.text = ""
		await fade_in_all_slots()
		if remaining_spins > 0:
			update_button_text()
			generate_all_rewards()
			open_button.disabled = false
			_auto_start_spin()
		else:
			open_button.hide()
			close_button.hide()
			open_button.disabled = false
			_auto_close()
	else:
		await get_tree().create_timer(1.5).timeout
		$Win_Label.text = ""
		await fade_in_all_slots()
		if remaining_spins > 0:
			update_button_text()
			generate_all_rewards()
			open_button.disabled = false
		else:
			open_button.hide()
			close_button.show()
			open_button.disabled = false

func _auto_close() -> void :
	var rect: Rect2 = get_viewport().get_visible_rect()
	var offscreen_pos = Vector2(rect.size.x + size.x, global_position.y)
	var tween = create_tween().tween_property(self, "global_position", offscreen_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	hide()

func fade_out_all_slots() -> void :
	var tween = create_tween().set_parallel(true)
	for slot in reward.get_children():
		tween.tween_property(slot, "modulate", Color(0.4, 0.4, 0.4, 1.0), 0.3)
		tween.tween_property(slot, "scale", Vector2.ONE, 0.3)
	await tween.finished

func fade_in_all_slots() -> void :
	var tween = create_tween().set_parallel(true)
	for slot in reward.get_children():
		tween.tween_property(slot, "modulate", Color.WHITE, 0.2)
		tween.tween_property(slot, "scale", Vector2.ONE, 0.2)
	await tween.finished

func calculate_eased_delay(progress: float) -> float:
	var min_delay = 0.03
	var max_delay = 0.15
	var t = 2.0 * progress - 1.0
	return min_delay + (max_delay - min_delay) * (t * t)

func highlight_sector(index: int) -> void :
	for i in range(8):
		var slot = reward.get_child(i)
		if i == index:
			slot.modulate = Color(1.5, 1.5, 1.5, 1.0)
			slot.scale = Vector2(1.15, 1.15)
		else:
			slot.modulate = Color(0.4, 0.4, 0.4, 1.0)
			slot.scale = Vector2.ONE

func blink_winner(winning_sector: int) -> void :
	var slot = reward.get_child(winning_sector)
	for i in range(3):
		slot.modulate = Color(0.4, 0.4, 0.4, 1.0)
		slot.scale = Vector2(1.15, 1.15)
		await get_tree().create_timer(0.15).timeout
		slot.modulate = Color(1.5, 1.5, 1.5, 1.0)
		slot.scale = Vector2(1.3, 1.3)
		await get_tree().create_timer(0.15).timeout

func process_wheel_result(winning_sector: int) -> void :
	var slot = reward.get_child(winning_sector)
	if slot.has_meta("upgrade_data"):
		var upgrade: Item = slot.get_meta("upgrade_data")
		var is_evolution: bool = upgrade is Weapon and upgrade.max_level_reached() and upgrade.evolution != null
		upgrade.upgrade_item()
		if is_evolution:
			$Win_Label.text = tr("EVOLUTION_LABEL") + "\n" + tr(upgrade.evolution.title) + "\n" + tr(upgrade.evolution.description)
		else:
			$Win_Label.text = tr("LEVEL_OPTION_SLOT") % upgrade.level + "/" + str(upgrade.upgrades.size() + 1) + "\n" + tr(upgrade.title) + "\n" + upgrade.upgrades[upgrade.level - 2].create_description()
	else:
		$Win_Label.text = "+" + tr("TR_CHIPS") % str(mchip.microchips)
		apply_upgrade()
	for i in range(8):
		if i != winning_sector:
			var s = reward.get_child(i)
			s.texture = null
			if s.has_meta("upgrade_data"):
				s.remove_meta("upgrade_data")

func reset_all_modulates() -> void :
	for slot in reward.get_children():
		slot.modulate = Color.WHITE
		slot.scale = Vector2.ONE

func clear_reward():
	for slot in reward.get_children():
		slot.texture = null
		slot.modulate = Color.WHITE
		slot.scale = Vector2.ONE
		if slot.has_meta("upgrade_data"):
			slot.remove_meta("upgrade_data")

func get_microchips_texture() -> Texture2D:
	return mchip.texture

func apply_upgrade():
	mchip.player_ref = owner
	mchip.activate()

func _on_close_pressed() -> void :
	var rect: Rect2 = get_viewport().get_visible_rect()
	var center: Vector2 = rect.position + rect.size / 2.0
	var offscreen_pos = Vector2(center.x - size.x / 2.0, rect.end.y + size.y)
	var tween = create_tween().tween_property(self, "global_position", offscreen_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = false
	hide()
