extends Node

const PORT := 7777
const DISCOVERY_PORT := 33333
const NAME_PATH := "user://net_settings.cfg"
const ROOM_MAX := 4
const MAX_CHAT_HISTORY := 100
signal peer_joined(id: int, pname: String)
signal peer_left(id: int)
signal peer_departed(id: int, pname: String)
signal peer_kicked(id: int, pname: String)
signal connected_to_server()
signal connection_failed()
signal auth_accepted()
signal auth_failed()
signal server_lost()
signal kicked()
signal game_started(scene_path: String)
signal chat_message(sender: String, text: String)
signal chat_history_received(history: Array)
signal enemy_snapshot_received(data: Array)
signal enemy_damage_received(enemy_id: int, damage: float, is_crit: bool)
signal pickup_snapshot_received(data: Array)
signal pickup_collected(pickup_id: int, collector_id: int)
signal projectile_snapshot_received(data: Array)
signal revive_zone_spawned(pos: Vector2, dead_player_id: int)
signal revive_zone_removed(dead_player_id: int)
signal all_players_dead()
var is_host := false
var session_active := false
var menu_scene: String = ""
var player_name: String = "Player"
var peer_names: Dictionary = {}
var peer_chars: Dictionary = {}
var _peers_connected: Dictionary = {}
var _kicked_ids: Dictionary = {}
var _chat_history: Array = []
var char_res_path: String = ""
var char_icon_path: String = ""
var char_tex_path: String = ""
var char_color: Color = Color.WHITE
var room_name: String = ""
var _room_password: String = ""
var _pending_password: String = ""
var _disc_sock: PacketPeerUDP = null
var _beacon_acc: float = 0.0
var _cfg: ConfigFile = ConfigFile.new()

func _ready() -> void:
	_cfg.load(NAME_PATH)
	player_name = _sanitize(_cfg.get_value("net", "name", "Player"))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	if not session_active:
		multiplayer.multiplayer_peer = null
		is_host = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		if multiplayer.has_multiplayer_peer() and session_active:
			stop.call_deferred()

func _sanitize(s: String) -> String:
	return str(s).replace("|", " ").strip_edges()

func is_valid_ip(s: String) -> bool:
	var parts = s.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int():
			return false
		var n = p.to_int()
		if n < 0 or n > 255:
			return false
		if p != str(n):
			return false
	return true

func save_name(new_name: String) -> void:
	player_name = _sanitize(new_name)
	if player_name == "":
		player_name = "Player"
	_cfg.set_value("net", "name", player_name)
	_cfg.save(NAME_PATH)

func set_character(char: Character) -> void:
	if char == null:
		return
	char_res_path = char.resource_path
	char_icon_path = char.icon.resource_path if char.icon != null else ""
	char_tex_path = char.texture.resource_path if char.texture != null else ""
	char_color = Color.from_string(char.color_trail, Color.WHITE)

func _char_dict() -> Dictionary:
	return {"res": char_res_path, "icon": char_icon_path, "tex": char_tex_path, "color": char_color}

func _register_peer(id: int, pname: String, chars: Dictionary) -> void:
	var is_new = not peer_names.has(id)
	peer_names[id] = pname
	peer_chars[id] = chars
	if is_new:
		peer_joined.emit(id, pname)

func _push_history(sender: String, text: String) -> void:
	_chat_history.append({"sender": sender, "text": text})
	if _chat_history.size() > MAX_CHAT_HISTORY:
		_chat_history.pop_front()

func set_pending_password(password: String) -> void:
	_pending_password = password

func players_count() -> int:
	return peer_names.size()

func has_password() -> bool:
	return _room_password != ""

func host(p_room_name: String, p_password: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, ROOM_MAX - 1)
	multiplayer.multiplayer_peer = peer
	is_host = true
	session_active = true
	room_name = _sanitize(p_room_name)
	if room_name == "":
		room_name = "Room"
	_room_password = p_password
	peer_names[1] = player_name
	peer_chars[1] = _char_dict()
	_chat_history.clear()
	_kicked_ids.clear()
	_disc_sock = PacketPeerUDP.new()
	_disc_sock.set_broadcast_enabled(true)
	_disc_sock.bind(DISCOVERY_PORT)
	_beacon_acc = 0.0
	return get_local_ip()

func join(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING:
		peer.close()
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	session_active = true
	_chat_history.clear()
	_kicked_ids.clear()

func send_chat(text: String) -> void:
	var clean = text.strip_edges()
	if clean == "":
		return
	chat_message.emit(player_name, clean)
	if is_host:
		_push_history(player_name, clean)
	_chat_msg.rpc(player_name, clean)

func kick_player(id: int) -> void:
	if not is_host or id == multiplayer.get_unique_id():
		return
	var pname = str(peer_names.get(id, "?"))
	_kick_notify.rpc_id(id)
	_kicked_ev.rpc(id, pname)
	_mark_kicked(id, pname)
	var peer = multiplayer.multiplayer_peer
	get_tree().create_timer(0.4).timeout.connect(func():
		if peer != null and peer.has_method("disconnect_peer") and _peers_connected.has(id):
			peer.disconnect_peer(id)
	)

func _mark_kicked(id: int, pname: String) -> void:
	_kicked_ids[id] = true
	peer_kicked.emit(id, pname)

func start_game(scene_path: String) -> void:
	if not is_host:
		return
	game_started.emit(scene_path)
	_start_game.rpc(scene_path)

func send_enemy_snapshot(data: Array) -> void:
	if not is_host:
		return
	_enemy_snap.rpc(data)

func send_enemy_damage(enemy_id: int, damage: float, is_crit: bool) -> void:
	_enemy_dmg.rpc(enemy_id, damage, is_crit)

func send_player_damage(target_id: int, amount: float) -> void:
	if not is_host:
		return
	_player_dmg.rpc_id(target_id, amount)

func send_pickup_snapshot(data: Array) -> void:
	if not is_host:
		return
	_pickup_snap.rpc(data)

func send_pickup_collected(pickup_id: int) -> void:
	_pickup_collect.rpc(pickup_id, multiplayer.get_unique_id())

func send_xp(target_id: int, amount: float) -> void:
	if not is_host:
		return
	_give_xp.rpc_id(target_id, amount)

func _on_peer_connected(id: int) -> void:
	_peers_connected[id] = true
	_announce.rpc_id(id, multiplayer.get_unique_id(), player_name, _char_dict())

func _on_peer_disconnected(id: int) -> void:
	var pname = str(peer_names.get(id, "?"))
	_peers_connected.erase(id)
	peer_names.erase(id)
	peer_chars.erase(id)
	if id == 1 and not is_host:
		if session_active:
			session_active = false
			stop()
			server_lost.emit()
		return
	peer_left.emit(id)
	if _kicked_ids.has(id):
		_kicked_ids.erase(id)
	else:
		peer_departed.emit(id, pname)

func stop() -> void:
	if not session_active and not multiplayer.has_multiplayer_peer():
		return
	var was_host = is_host
	if was_host and multiplayer.has_multiplayer_peer():
		_host_leaving.rpc()
		var peer = multiplayer.multiplayer_peer
		if is_inside_tree():
			get_tree().create_timer(0.35).timeout.connect(func():
				if multiplayer.multiplayer_peer == peer:
					multiplayer.multiplayer_peer = null
			)
		else:
			multiplayer.multiplayer_peer = null
	else:
		multiplayer.multiplayer_peer = null
	is_host = false
	session_active = false
	room_name = ""
	_room_password = ""
	_pending_password = ""
	peer_names.clear()
	peer_chars.clear()
	_peers_connected.clear()
	_kicked_ids.clear()
	_chat_history.clear()
	if _disc_sock != null:
		_disc_sock.close()
		_disc_sock = null

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	peer_names[my_id] = player_name
	peer_chars[my_id] = _char_dict()
	connected_to_server.emit()
	_try_auth.rpc_id(1, _pending_password, player_name, _char_dict())

func _on_connection_failed() -> void:
	stop()
	connection_failed.emit()

@rpc("any_peer", "reliable")
func _announce(id: int, pname: String, chars: Dictionary) -> void:
	_register_peer(id, pname, chars)

@rpc("any_peer", "reliable")
func _try_auth(password: String, pname: String, chars: Dictionary) -> void:
	if not is_host:
		return
	var sender = multiplayer.get_remote_sender_id()
	if password != _room_password:
		_auth_fail.rpc_id(sender)
		return
	_register_peer(sender, pname, chars)
	_auth_ok.rpc_id(sender, room_name)
	_roster.rpc_id(sender, _build_roster(sender))
	_member_joined.rpc(sender, pname, chars)
	_chat_history_sync.rpc_id(sender, _chat_history.duplicate())

@rpc("authority", "reliable")
func _member_joined(id: int, pname: String, chars: Dictionary) -> void:
	if id == multiplayer.get_unique_id():
		return
	_register_peer(id, pname, chars)

@rpc("authority", "reliable")
func _chat_history_sync(history: Array) -> void:
	chat_history_received.emit(history)

@rpc("authority", "reliable")
func _auth_ok(rname: String) -> void:
	room_name = rname
	_pending_password = ""
	auth_accepted.emit()

@rpc("authority", "reliable")
func _auth_fail() -> void:
	stop()
	auth_failed.emit()

@rpc("authority", "reliable")
func _roster(entries: Array) -> void:
	for e in entries:
		var id = int(e.get("id", 0))
		if id == multiplayer.get_unique_id():
			continue
		_register_peer(id, str(e.get("name", "?")), e.get("chars", {}))

@rpc("any_peer", "reliable")
func _chat_msg(sender: String, text: String) -> void:
	if is_host:
		_push_history(sender, text)
	chat_message.emit(sender, text)

@rpc("authority", "reliable")
func _kick_notify() -> void:
	stop()
	kicked.emit()

@rpc("authority", "reliable")
func _kicked_ev(id: int, pname: String) -> void:
	if id == multiplayer.get_unique_id():
		return
	_mark_kicked(id, pname)

@rpc("authority", "reliable")
func _host_leaving() -> void:
	if is_host or not session_active:
		return
	stop()
	server_lost.emit()

@rpc("authority", "reliable")
func _start_game(scene_path: String) -> void:
	game_started.emit(scene_path)

@rpc("authority", "unreliable_ordered")
func _enemy_snap(data: Array) -> void:
	enemy_snapshot_received.emit(data)

@rpc("any_peer", "unreliable_ordered")
func _enemy_dmg(enemy_id: int, damage: float, is_crit: bool) -> void:
	enemy_damage_received.emit(enemy_id, damage, is_crit)

@rpc("authority", "reliable")
func _player_dmg(amount: float) -> void:
	var p = get_tree().get_first_node_in_group("Player")
	if p and p.has_method("take_damage"):
		p.take_damage(amount)

@rpc("authority", "unreliable_ordered")
func _pickup_snap(data: Array) -> void:
	pickup_snapshot_received.emit(data)

@rpc("any_peer", "reliable")
func _pickup_collect(pickup_id: int, collector_id: int) -> void:
	pickup_collected.emit(pickup_id, collector_id)

@rpc("authority", "reliable")
func _give_xp(amount: float) -> void:
	var p = get_tree().get_first_node_in_group("Player")
	if p and p.has_method("gain_XP"):
		p.gain_XP(amount)

@rpc("authority", "unreliable_ordered")
func _projectile_snap(data: Array) -> void:
	projectile_snapshot_received.emit(data)

@rpc("any_peer", "reliable")
func _request_revive_zone(pos: Vector2, dead_player_id: int) -> void:
	if not is_host:
		return
	spawn_revive_zone(pos, dead_player_id)

@rpc("authority", "reliable")
func _spawn_revive_zone(pos: Vector2, dead_player_id: int) -> void:
	revive_zone_spawned.emit(pos, dead_player_id)

@rpc("any_peer", "reliable")
func _revive_request(target_id: int) -> void:
	if not is_host:
		return
	_revive_broadcast.rpc(target_id)

@rpc("authority", "reliable", "call_local")
func _revive_broadcast(target_id: int) -> void:
	var my_id = multiplayer.get_unique_id()
	if target_id == my_id:
		var local_player = get_tree().get_first_node_in_group("Player")
		if local_player and local_player.has_method("revive") and local_player.is_dead:
			local_player.revive()
	var dummy = get_tree().get_first_node_in_group("RemotePlayers_%d" % target_id)
	if dummy and dummy.has_method("network_revive"):
		dummy.network_revive()

func send_projectile_snapshot(data: Array) -> void:
	if not is_host:
		return
	_projectile_snap.rpc(data)

func request_revive_zone(pos: Vector2, dead_player_id: int) -> void:
	if multiplayer.get_unique_id() == 1:
		spawn_revive_zone(pos, dead_player_id)
	else:
		_request_revive_zone.rpc_id(1, pos, dead_player_id)

func spawn_revive_zone(pos: Vector2, dead_player_id: int) -> void:
	if not is_host:
		return
	revive_zone_spawned.emit(pos, dead_player_id)
	_spawn_revive_zone.rpc(pos, dead_player_id)

func remove_revive_zone(dead_player_id: int) -> void:
	if multiplayer.get_unique_id() == 1:
		revive_zone_removed.emit(dead_player_id)
		_remove_revive_zone.rpc(dead_player_id)
	else:
		_request_remove_revive_zone.rpc_id(1, dead_player_id)

@rpc("any_peer", "reliable")
func _request_remove_revive_zone(dead_player_id: int) -> void:
	if not is_host:
		return
	revive_zone_removed.emit(dead_player_id)
	_remove_revive_zone.rpc(dead_player_id)

@rpc("authority", "reliable")
func _remove_revive_zone(dead_player_id: int) -> void:
	revive_zone_removed.emit(dead_player_id)

func broadcast_all_players_dead() -> void:
	if not is_host:
		return
	_all_players_dead_event.rpc()

@rpc("authority", "reliable")
func _all_players_dead_event() -> void:
	all_players_dead.emit()
func send_revive_player(target_id: int) -> void:
	if multiplayer.get_unique_id() == 1:
		_process_revive(target_id)
	else:
		_revive_request.rpc_id(1, target_id)
func send_revive_progress(dead_player_id: int, progress: float) -> void:
	_revive_zone_progress.rpc(dead_player_id, progress)
func _process_revive(target_id: int) -> void:
	if not is_host:
		return
	var dummy = get_tree().get_first_node_in_group("RemotePlayers_%d" % target_id)
	if dummy and "_is_dead_dummy" in dummy and not dummy._is_dead_dummy:
		return
	var local_player = get_tree().get_first_node_in_group("Player")
	if target_id == multiplayer.get_unique_id() and local_player and not local_player.is_dead:
		return
	_revive_broadcast.rpc(target_id)

func _build_roster(exclude_id: int) -> Array:
	var out: Array = []
	for id in peer_names:
		if id == exclude_id:
			continue
		out.append({"id": id, "name": peer_names[id], "chars": peer_chars.get(id, {})})
	return out

func _send_pong(ip: String, port: int) -> void:
	if _disc_sock == null:
		return
	_disc_sock.set_dest_address(ip, port)
	var pong = "PONG|%s|%s|%d|%d|%d" % [room_name, player_name, players_count(), ROOM_MAX, 1 if has_password() else 0]
	_disc_sock.put_packet(pong.to_utf8_buffer())

func _process(delta: float) -> void:
	if _disc_sock == null:
		return
	if is_host:
		_beacon_acc += delta
		if _beacon_acc >= 0.4:
			_beacon_acc = 0.0
			_send_pong("255.255.255.255", DISCOVERY_PORT)
	while _disc_sock.get_available_packet_count() > 0:
		var msg = _disc_sock.get_packet().get_string_from_utf8()
		var from = _disc_sock.get_packet_ip()
		var from_port = _disc_sock.get_packet_port()
		if msg == "PING":
			_send_pong(from, from_port)

func discover(timeout := 2.0) -> Array:
	var sock := PacketPeerUDP.new()
	sock.set_broadcast_enabled(true)
	if sock.bind(DISCOVERY_PORT) != OK:
		sock.close()
		sock = PacketPeerUDP.new()
		sock.set_broadcast_enabled(true)
		sock.bind(0)
	sock.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	sock.put_packet("PING".to_utf8_buffer())
	var seen: Dictionary = {}
	var result: Array = []
	var t := 0.0
	while t < timeout:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		while sock.get_available_packet_count() > 0:
			var s = sock.get_packet().get_string_from_utf8()
			if not s.begins_with("PONG|"):
				continue
			var ip = sock.get_packet_ip()
			if seen.has(ip):
				continue
			seen[ip] = true
			var parts = s.split("|")
			if parts.size() < 6:
				continue
			var rname = parts[1]
			if rname == "":
				rname = parts[2] + "'s Room"
			result.append({"ip": ip, "name": rname, "host": parts[2], "players": int(parts[3]), "max": int(parts[4]), "has_password": parts[5] == "1", "idx": result.size()})
	sock.close()
	return result

signal revive_zone_progress_updated(dead_player_id: int, progress: float)

func broadcast_revive_progress(dead_player_id: int, progress: float) -> void:
	if not is_host:
		return
	_revive_zone_progress.rpc(dead_player_id, progress)

@rpc("any_peer", "unreliable_ordered")
func _revive_zone_progress(dead_player_id: int, progress: float) -> void:
	revive_zone_progress_updated.emit(dead_player_id, progress)

func get_local_ip() -> String:
	for iface in IP.get_local_interfaces():
		for addr in iface.addresses:
			if addr.contains(".") and not addr.begins_with("127."):
				return addr
	return ""
