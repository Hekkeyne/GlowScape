extends Node

@export var dummy_scene: PackedScene

func _ready() -> void :
	for id in Net.peer_names:
		_spawn(id, str(Net.peer_names[id]))
	Net.peer_joined.connect(_spawn)
	Net.peer_left.connect(_on_left)
	Net.server_lost.connect(_on_server_lost)

func _exit_tree() -> void :
	if Net.is_host and Net.session_active:
		Net.stop()

func _spawn(id: int, pname: String) -> void :
	if id == multiplayer.get_unique_id():
		return
	if get_tree().get_first_node_in_group("RemotePlayers_%d" % id) != null:
		return
	var chars: Dictionary = Net.peer_chars.get(id, {})
	var d = dummy_scene.instantiate()
	add_child(d)
	d.setup(id, pname, str(chars.get("tex", "")), chars.get("color", Color.WHITE))

func _on_left(id: int) -> void :
	var n = get_tree().get_first_node_in_group("RemotePlayers_%d" % id)
	if n:
		n.queue_free()
	_check_all_dead()

func _check_all_dead() -> void :
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_all_players_dead") and player.has_method("_show_exit_button"):
		if player._all_players_dead():
			player._show_exit_button()

func _on_server_lost() -> void :
	if Net.is_host:
		return
	if Net.menu_scene != "":
		SceneChanger.change_scene(Net.menu_scene)
