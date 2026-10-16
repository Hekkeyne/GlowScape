extends Node2D

@onready var scene_changer: CanvasLayer = get_node_or_null("/root/SceneChanger")

func _ready() -> void:
	Net.server_lost.connect(_on_server_lost)
	Net.kicked.connect(_on_kicked)
	Net.all_players_dead.connect(_on_all_players_dead)

func _on_all_players_dead() -> void:
	get_tree().paused = true
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("_show_exit_button"):
		player._show_exit_button()

func _on_server_lost() -> void:
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self) and get_tree().current_scene == self:
		get_tree().paused = false
		_change_to_menu()

func _on_kicked() -> void:
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self) and get_tree().current_scene == self:
		get_tree().paused = false
		_change_to_menu()

func _change_to_menu() -> void:
	var path = "res://scene/main_menu.tscn"
	if scene_changer and scene_changer.has_method("change_scene"):
		scene_changer.change_scene(path)
	else:
		get_tree().change_scene_to_file(path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		if multiplayer.has_multiplayer_peer() and Net.session_active:
			Net.stop()
