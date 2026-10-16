extends Node

@export var enemy_dummy_scene: PackedScene
@export var snapshot_interval: float = 0.05

var _snap_acc: float = 0.0
var _dummies: Dictionary = {}

func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if Net.is_host:
		Net.enemy_damage_received.connect(_on_enemy_damage)
	else:
		Net.enemy_snapshot_received.connect(_on_snapshot)

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not Net.is_host:
		return
	_snap_acc += delta
	if _snap_acc >= snapshot_interval:
		_snap_acc = 0.0
		_send_snapshot()

func _send_snapshot() -> void:
	var data: Array = []
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(enemy):
			continue
		var e = enemy as EnemyBase
		if e == null or e.net_id == 0:
			continue
		var type_path = ""
		if e.type != null:
			type_path = e.type.resource_path
		var anim_name := ""
		var flip_h := false
		if e.visual_node is AnimatedSprite2D:
			anim_name = e.visual_node.animation
			flip_h = e.visual_node.flip_h
		elif e.visual_node is Sprite2D:
			flip_h = e.visual_node.flip_h
		data.append({
			"id": e.net_id,
			"type": type_path,
			"pos": e.global_position,
			"rot": e.rotation,
			"scale": e.scale,
			"hp": e.health,
			"max_hp": e.type.health if e.type else 100.0,
			"elite": e.is_elite,
			"anim": anim_name,
			"flip": flip_h,
			"dying": e.is_dying,
		})
	if data.size() > 0:
		Net.send_enemy_snapshot(data)

func _on_snapshot(data: Array) -> void:
	var seen_ids: Dictionary = {}
	for entry in data:
		var id = int(entry.get("id", 0))
		if id == 0:
			continue
		seen_ids[id] = true
		if not _dummies.has(id):
			_spawn_dummy(id, entry)
		else:
			_update_dummy(id, entry)
	for id in _dummies.keys():
		if not seen_ids.has(id):
			if is_instance_valid(_dummies[id]):
				_dummies[id].queue_free()
			_dummies.erase(id)

func _spawn_dummy(id: int, entry: Dictionary) -> void:
	if enemy_dummy_scene == null:
		return
	var dummy = enemy_dummy_scene.instantiate()
	get_tree().current_scene.add_child(dummy)
	if entry.has("pos"):
		dummy.global_position = entry.pos
	_dummies[id] = dummy
	_update_dummy(id, entry)

func _update_dummy(id: int, entry: Dictionary) -> void:
	var dummy = _dummies.get(id)
	if not is_instance_valid(dummy):
		_dummies.erase(id)
		return
	dummy.update_from_snapshot(entry)

func _on_enemy_damage(enemy_id: int, amount: float, is_crit: bool) -> void:
	if not Net.is_host:
		return
	for node in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(node):
			continue
		var e = node as EnemyBase
		if e == null or e.net_id != enemy_id or e.is_dying or e.invincible:
			continue
		e.health -= amount
		e._spawn_damage_popup(amount, is_crit)
		e._flash_damage()
		if e.health <= 0.0:
			e.die()
		return
