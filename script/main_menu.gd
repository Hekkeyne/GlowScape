extends Control

@onready var custom_dialog = $Confirm_upgrade
@onready var sim_battle: Node2D = $Menu/SimPanel/SimBattle

signal off_play
signal multiplayer_room_created(ip: String)
signal multiplayer_room_joined(ip: String)
signal multiplayer_room_closed()

@export var battle_scene: String = "res://scene/testworld.tscn"

var _multiplayer_unlocked: bool = false
var _joining_room_name: String = ""
var _join_by_ip: bool = false

func _update_sim_visibility() -> void:
	if sim_battle == null:
		return
	var is_menu_visible = $Menu.visible
	sim_battle._update_visibility(is_menu_visible)

func _ready() -> void:
	$Weapon_select.hide()
	$CharacterUpgrade.hide()
	$Menu.show()
	$Beastiary.hide()
	$FSkillTree.hide()
	$SettingsPanel.hide()
	$Multiplayer.hide()
	$MultiplayerRoom.hide()
	$Menu/BackGround_Shader.material.set_shader_parameter("g_random_seed", randf_range(0, 100))
	_lock_multiplayer()
	start_shader_speed_loop()
	connect_skill_buttons($FSkillTree)
	$CharacterUpgrade.stats_changed.connect(_on_meta_stats_changed)
	_wire_multiplayer_panel()
	_wire_multiplayer_room()
	Net.menu_scene = scene_file_path
	_update_sim_visibility()

func _wire_multiplayer_panel() -> void:
	var panel = $Multiplayer
	panel.refresh_requested.connect(_on_mp_refresh)
	panel.create_requested.connect(_on_mp_create)
	panel.connect_requested.connect(_on_mp_connect)
	panel.direct_join_requested.connect(_on_mp_direct_join)
	Net.auth_accepted.connect(_on_mp_auth_accepted)
	Net.auth_failed.connect(_on_mp_auth_failed)
	Net.connection_failed.connect(_on_mp_connection_failed)
	Net.server_lost.connect(_on_mp_server_lost)

func _wire_multiplayer_room() -> void:
	var room = $MultiplayerRoom
	room.start_requested.connect(_on_room_start)
	room.leave_requested.connect(_on_room_leave)
	Net.kicked.connect(_on_kicked)
	Net.game_started.connect(_on_game_started)

func _on_meta_stats_changed() -> void:
	if Persistence.character != null:
		%StatsRows.show_stats(Persistence.get_combined_stats(Persistence.character.base_stats, Persistence.character))

func connect_skill_buttons(node: Node) -> void:
	for child in node.get_children():
		if child.has_signal("r_upgrade_confirm"):
			child.r_upgrade_confirm.connect(_on_upgrade_r_upgrade_confirm)
		if child.get_child_count() > 0:
			connect_skill_buttons(child)

func _lock_multiplayer() -> void:
	_multiplayer_unlocked = false
	%Multiplayer.disabled = true
	%Multiplayer/Label.text = tr("SELECT_A_CHARACTER")
	_update_sim_visibility()

func unlock_multiplayer() -> void:
	_multiplayer_unlocked = true
	%Multiplayer.disabled = false
	%Multiplayer/Label.text = tr("MULTIPLAYER_BUTTON")
	_update_sim_visibility()

func menu1():
	$Menu.show()
	$Menu.global_position.y = $Beastiary.global_position.y + $Beastiary.size.y
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Beastiary, "global_position:y", -$Beastiary.size.y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Menu, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Beastiary.hide()
	_update_sim_visibility()

func menu2(): 
	$Menu.show()
	$Menu.global_position.x = $FSkillTree.global_position.x + $FSkillTree.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($FSkillTree, "global_position:x", -$FSkillTree.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Menu, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$FSkillTree.hide()
	_update_sim_visibility()

func menu3():
	$Menu.show()
	$Menu.global_position.x = $Weapon_select.global_position.x - $Menu.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Weapon_select, "global_position:x", $Weapon_select.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Menu, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Weapon_select.hide()
	_update_sim_visibility()

func menu4():
	$Menu.show()
	$Menu.global_position.y = $SettingsPanel.global_position.y - $Menu.size.y
	var tween = create_tween().set_parallel(true)
	tween.tween_property($SettingsPanel, "global_position:y", $SettingsPanel.size.y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Menu, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$SettingsPanel.hide()
	_update_sim_visibility()

func menu5():
	$CharacterUpgrade.show()
	$CharacterUpgrade.global_position.y = get_viewport().get_visible_rect().size.y
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Weapon_select, "global_position:y", -$Weapon_select.size.y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($CharacterUpgrade, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Weapon_select.hide()
	_update_sim_visibility()

func menu6():
	$Weapon_select.show()
	$Weapon_select.global_position.y = -$Weapon_select.size.y
	var tween = create_tween().set_parallel(true)
	tween.tween_property($CharacterUpgrade, "global_position:y", get_viewport().get_visible_rect().size.y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Weapon_select, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$CharacterUpgrade.hide()
	_update_sim_visibility()

func menu7():
	$Menu.show()
	$Menu.global_position.x = $Multiplayer.global_position.x - $Menu.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Multiplayer, "global_position:x", $Multiplayer.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Menu, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Multiplayer.hide()
	_update_sim_visibility()

func menu8():
	$Multiplayer.show()
	$Multiplayer.global_position.x = $Menu.global_position.x + $Menu.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Menu, "global_position:x", -$Menu.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Multiplayer, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Menu.hide()
	_update_sim_visibility()

func mp_open():
	if not _multiplayer_unlocked:
		return
	$Multiplayer.show()
	$Multiplayer.global_position.x = $Weapon_select.global_position.x + $Weapon_select.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Weapon_select, "global_position:x", -$Weapon_select.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Multiplayer, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Weapon_select.hide()
	_update_sim_visibility()

func mp_close():
	$Weapon_select.show()
	$Weapon_select.global_position.x = -$Weapon_select.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Multiplayer, "global_position:x", $Multiplayer.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Weapon_select, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Multiplayer.hide()
	_update_sim_visibility()

func room_open():
	$MultiplayerRoom.show()
	$MultiplayerRoom.global_position.x = $Multiplayer.global_position.x + $Multiplayer.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Multiplayer, "global_position:x", -$Multiplayer.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($MultiplayerRoom, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Multiplayer.hide()
	$MultiplayerRoom.refresh()
	_update_sim_visibility()

func room_close_to_multiplayer():
	if not $MultiplayerRoom.visible:
		return
	$Multiplayer.show()
	$Multiplayer.global_position.x = -$Multiplayer.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($MultiplayerRoom, "global_position:x", $MultiplayerRoom.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Multiplayer, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$MultiplayerRoom.hide()
	_update_sim_visibility()

func settings():
	$SettingsPanel.show()
	$SettingsPanel.global_position.y = $Menu.global_position.y + $Menu.size.y
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Menu, "global_position:y", -$Menu.size.y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($SettingsPanel, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Menu.hide()
	_update_sim_visibility()

func skill_tree(): 
	$FSkillTree.show()
	$FSkillTree.global_position.x = $Menu.global_position.x - $FSkillTree.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Menu, "global_position:x", $Menu.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($FSkillTree, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Menu.hide()
	_update_sim_visibility()

func beastiary(): 
	$Beastiary.show()
	$Beastiary.global_position.y = $Menu.global_position.y - $Beastiary.size.y
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Menu, "global_position:y", $Menu.size.y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Beastiary, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Menu.hide()
	_update_sim_visibility()

func weapon_select():
	$Weapon_select/VBoxContainer/Play/Label.text = tr("SELECT_A_CHARACTER")
	$Weapon_select/VBoxContainer/Multiplayer/Label.text = tr("SELECT_A_CHARACTER")
	$Weapon_select/charactr_panel/ScrollContainer/Character.load_characters()
	_connect_character_buttons()
	$Weapon_select.show()
	$Weapon_select.global_position.x = $Menu.global_position.x + $Menu.size.x
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Menu, "global_position:x", -$Menu.size.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Weapon_select, "global_position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Menu.hide()
	_update_sim_visibility()

func _connect_character_buttons() -> void:
	var character_container = $Weapon_select/charactr_panel/ScrollContainer/Character
	for child in character_container.get_children():
		if child.has_signal("pressed") and not child.pressed.is_connected(_on_character_picked):
			child.pressed.connect(_on_character_picked)

func _on_character_picked() -> void:
	unlock_multiplayer()
	if Persistence.character != null:
		Net.set_character(Persistence.character)

func _on_beastiary_pressed() -> void:
	$Beastiary/Information.hide()
	beastiary()
	$background_Music.stream = load("res://resourse/music/Beatiary.ogg")
	$background_Music.play()
	_update_sim_visibility()

func _on_upgrades_pressed() -> void:
	skill_tree()
	$background_Music.stream = load("res://resourse/music/upgrades.ogg")
	$background_Music.play()
	_update_sim_visibility()

func _on_start_pressed() -> void:
	weapon_select()
	_update_sim_visibility()

func _on_multiplayer_pressed() -> void:
	mp_open()
	_refresh_rooms()

func _on_back_multiplayer_pressed() -> void:
	mp_close()
	Net.stop()
	multiplayer_room_closed.emit()
	$Multiplayer.clear_status()
	if _multiplayer_unlocked:
		%Multiplayer/Label.text = tr("MULTIPLAYER_BUTTON")
	_update_sim_visibility()

func _on_back_beast_pressed() -> void:
	menu1()
	$background_Music.stream = load("res://resourse/music/in_menu.ogg")
	$background_Music.play()
	_update_sim_visibility()

func _on_back_upgrade_pressed() -> void:
	menu2() 
	$background_Music.stream = load("res://resourse/music/in_menu.ogg")
	$background_Music.play()
	_update_sim_visibility()

func _on_back_weapon_pressed() -> void:
	menu3()
	emit_signal("off_play")
	%StatsRows.show_stats(null)
	%StartingWeapon.texture=null
	for child in $Weapon_select/charactr_panel/ScrollContainer/Character.get_children():
		child.queue_free()
	%Play/Label.text = tr("SELECT_A_CHARACTER")
	%Play.disabled=true
	_lock_multiplayer()
	if multiplayer.has_multiplayer_peer():
		Net.stop()
		multiplayer_room_closed.emit()
	$Weapon_select/TitleStartingWeapon.text=""
	_update_sim_visibility()

func start_shader_speed_loop() -> void:
	var tween = create_tween()
	var transition_time = randf_range(5.0, 11.0)
	var dir_x = 1.0 if randi() % 2 == 0 else -1.0
	var dir_y = 1.0 if randi() % 2 == 0 else -1.0
	var target_speed = Vector2(randf_range(0.1, 0.1) * dir_x, randf_range(0.1, 0.1) * dir_y)
	tween.tween_property($Menu/BackGround_Shader.material, "shader_parameter/g_speed", target_speed, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) 
	var next_color = Color(randf(), randf(), randf())
	tween.tween_property($Menu/BackGround_Shader.material, "shader_parameter/g_color_a", next_color, transition_time)
	tween.finished.connect(start_shader_speed_loop)

func _on_upgrade_r_upgrade_confirm(upgrade: Skill, on_confirm: Callable) -> void:
	custom_dialog.show_dialog(upgrade, on_confirm)

func _on_setting_button_pressed() -> void:
	settings()
	$background_Music.stream = load("res://resourse/music/settings.ogg")
	$background_Music.play()
	_update_sim_visibility()

func _on_back_setting_pressed() -> void:
	menu4()
	$background_Music.stream = load("res://resourse/music/in_menu.ogg")
	$background_Music.play()
	_update_sim_visibility()

func _on_upgrade_char_pressed() -> void:
	menu5()
	_update_sim_visibility()

func _on_back_charcter_upgrade_pressed() -> void:
	menu6()
	_update_sim_visibility()

func on_multiplayer_room_created(ip: String) -> void:
	%Multiplayer/Label.text = tr("HOSTING_LABEL") % ip
	multiplayer_room_created.emit(ip)

func on_multiplayer_room_joined(ip: String) -> void:
	%Multiplayer/Label.text = tr("CONNECTED_LABEL") % ip
	multiplayer_room_joined.emit(ip)

func on_multiplayer_game_start() -> void:
	%Multiplayer/Label.text = tr("IN_GAME_LABEL")

func _refresh_rooms() -> void:
	var panel = $Multiplayer
	panel.set_status_busy(tr("SCANNING_LABEL"))
	var rooms = await Net.discover()
	if not is_instance_valid(panel):
		return
	panel.set_rooms(rooms)

func _on_mp_refresh() -> void:
	_refresh_rooms()

func _on_mp_create(room_name: String, password: String) -> void:
	if Persistence.character != null:
		Net.set_character(Persistence.character)
	$MultiplayerRoom.reset_view()
	var ip = Net.host(room_name, password)
	on_multiplayer_room_created(ip)
	room_open()

func _on_mp_connect(room: Dictionary, password: String) -> void:
	if Persistence.character != null:
		Net.set_character(Persistence.character)
	$MultiplayerRoom.reset_view()
	_join_by_ip = false
	_joining_room_name = str(room.get("name", "?"))
	Net.set_pending_password(password)
	Net.join(str(room.get("ip", "")))
	$Multiplayer.set_status_busy(tr("AUTHENTICATING_LABEL"))

func _on_mp_direct_join(ip: String, password: String) -> void:
	if Persistence.character != null:
		Net.set_character(Persistence.character)
	$MultiplayerRoom.reset_view()
	_join_by_ip = true
	_joining_room_name = ""
	Net.set_pending_password(password)
	Net.join(ip)
	$Multiplayer.set_status_busy(tr("AUTHENTICATING_LABEL"))

func _on_mp_auth_accepted() -> void:
	on_multiplayer_room_joined(Net.get_local_ip())
	room_open()

func _on_mp_auth_failed() -> void:
	$Multiplayer.set_status_text(tr("WRONG_PASSWORD_LABEL"))

func _on_mp_connection_failed() -> void:
	if _join_by_ip:
		$Multiplayer.set_status_text(tr("IP_ERROR_LABEL"))
	else:
		$Multiplayer.set_status_text(tr("CONNECTION_FAILED_LABEL"))

func _on_mp_server_lost() -> void:
	room_close_to_multiplayer()
	$MultiplayerRoom.reset_view()
	$Multiplayer.set_status_text(tr("HOST_LEFT_LABEL"))

func _on_kicked() -> void:
	room_close_to_multiplayer()
	$MultiplayerRoom.reset_view()
	$Multiplayer.set_status_text(tr("KICKED_LABEL"))

func _on_room_start() -> void:
	on_multiplayer_game_start()
	Net.start_game(battle_scene)

func _on_leave_button_pressed() -> void:
	_on_room_leave()

func _on_room_leave() -> void:
	if not Net.session_active:
		return
	Net.stop()
	multiplayer_room_closed.emit()
	room_close_to_multiplayer()
	$MultiplayerRoom.reset_view()
	$Multiplayer.set_info_text(tr("LEFT_ROOM_LABEL"))

func _on_game_started(scene_path: String) -> void:
	SceneChanger.change_scene(scene_path)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
