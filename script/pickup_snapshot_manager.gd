extends Node

@export var pickup_dummy_scene: PackedScene
@export var snapshot_interval: float = 0.05

var _snap_acc: float = 0.0
var _dummies: Dictionary = {}

func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if Net.is_host:
		Net.pickup_collected.connect(_on_pickup_collected)
	else:
		Net.pickup_snapshot_received.connect(_on_snapshot)

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
	for pickup in get_tree().get_nodes_in_group("PickupNet"):
		if not is_instance_valid(pickup):
			continue
		if pickup.net_id == 0:
			continue
		var type_path = ""
		if pickup.type != null:
			type_path = pickup.type.resource_path
		data.append({
			"id": pickup.net_id,
			"pos": pickup.global_position,
			"type": type_path,
			"is_mega": pickup.is_mega,
			"bonus_xp": pickup.bonus_xp,
		})
	if data.size() > 0:
		Net.send_pickup_snapshot(data)

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
	if pickup_dummy_scene == null:
		return
	var dummy = pickup_dummy_scene.instantiate()
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

func _on_pickup_collected(pickup_id: int, collector_id: int) -> void:
	if not Net.is_host:
		return
	for pickup in get_tree().get_nodes_in_group("PickupNet"):
		if not is_instance_valid(pickup):
			continue
		if pickup.net_id == pickup_id:
			pickup._apply_collection(collector_id)
			return
