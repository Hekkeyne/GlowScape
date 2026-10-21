extends Node2D

@export var sim_player_scene: PackedScene
@export var enemy_types: Array[Resource] = []
@export var characters: Array[Resource] = []
@export var weapons: Array[Resource] = []
@export var min_enemies: = 4
@export var max_enemies: = 8
@export var transition_min: = 18.0
@export var transition_max: = 32.0
@export var arena_margin: = 30.0
@export var world_scale: = 1.0
@export var overlay_alpha: = 0.35

var _player: CharacterBody2D = null
var _overlay: ColorRect = null
var _trans_t: = 0.0
var _busy: = false
var _arena: = Rect2()
var _initialized: = false

func _ready() -> void :
	_initialize()

func _initialize() -> void :
	if _initialized:
		return
	_initialized = true
	scale = Vector2.ONE * world_scale
	_compute_arena()
	_setup_overlay()
	_setup_player()
	_setup_deferred.call_deferred()
	_trans_t = randf_range(transition_min, transition_max)

func _setup_deferred() -> void :
	_new_loadout()
	if _player and is_instance_valid(_player):
		_player.global_position = _random_pos_in_arena()
	_spawn_wave()

func _update_visibility(is_visible: bool) -> void :
	if is_visible:
		if not _initialized:
			_initialize()
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_clear_all()
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED

func _clear_all() -> void :
	_initialized = false
	if _player and is_instance_valid(_player):
		_player.queue_free()
		_player = null
	_clear_enemies()
	_contain_projectiles()
	_contain_enemies()
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_busy = false
	_trans_t = 0.0

func _compute_arena() -> void :
	var panel = get_parent() as Control
	if panel:
		_arena = Rect2(panel.global_position, panel.size).grow( - arena_margin)
	else:
		var vp_size = get_viewport().get_visible_rect().size
		_arena = Rect2(Vector2.ZERO, vp_size).grow( - arena_margin)

func _process(delta: float) -> void :
	_compute_arena()
	if _player and is_instance_valid(_player):
		_player.arena = _arena
	_contain_projectiles()
	_contain_enemies()
	for e in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(e) and e.type != null:
			if "drops" in e.type and e.type.drops.size() > 0:
				e.type.drops.clear()
				_clear_enemy_drops(e)
	if _busy:
		return
	_trans_t -= delta
	if _trans_t <= 0.0:
		_transition()
		return
	var alive: = 0
	for e in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(e) and not e.is_dying:
			alive += 1
	if alive < min_enemies:
		_spawn_wave()

func _setup_overlay() -> void :
	var panel = get_parent() as Control
	if panel == null:
		return
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, overlay_alpha)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child.call_deferred(_overlay)
	_overlay.set_anchors_preset.call_deferred(Control.PRESET_FULL_RECT)

func _setup_player() -> void :
	if sim_player_scene == null:
		push_warning("MenuSim: sim_player_scene not set")
		return
	_player = sim_player_scene.instantiate()
	add_child.call_deferred(_player)
	_player.arena = _arena
	_player.died.connect(_on_player_died)

func _on_player_died() -> void :
	if not _busy:
		_transition()

func _transition() -> void :
	_busy = true
	if _overlay and is_instance_valid(_overlay):
		var tw = create_tween()
		tw.tween_property(_overlay, "color:a", 0.9, 0.5)
		await tw.finished
	_clear_enemies()
	_new_loadout()
	_respawn_player()
	_spawn_wave()
	_trans_t = randf_range(transition_min, transition_max)
	if _overlay and is_instance_valid(_overlay):
		var tw2 = create_tween()
		tw2.tween_property(_overlay, "color:a", overlay_alpha, 0.7)
		await tw2.finished
	_busy = false

func _new_loadout() -> void :
	if _player == null or not is_instance_valid(_player):
		return
	var ch = characters.pick_random() if not characters.is_empty() else null
	var ws: Array = []
	if not weapons.is_empty():
		var pool = weapons.duplicate()
		pool.shuffle()
		for i in range(mini(randi_range(3, 6), pool.size())):
			ws.append(pool[i])
	_player.setup(ch, ws)

func _respawn_player() -> void :
	if _player == null or not is_instance_valid(_player):
		return
	_player.global_position = _random_pos_in_arena()
	_player.setup(_player.character, _player.weapons)

func _spawn_wave() -> void :
	if _player == null or not is_instance_valid(_player):
		return
	if enemy_types.is_empty():
		push_warning("MenuSim: enemy_types is empty")
		return
	var count: = randi_range(min_enemies, max_enemies)
	for i in range(count):
		var base_type = enemy_types.pick_random()
		if base_type == null:
			continue
		var scene = base_type.scene if "scene" in base_type else null
		if scene == null:
			continue
		var type_copy = base_type.duplicate(true)
		if "drops" in type_copy:
			type_copy.drops.clear()
		var e = scene.instantiate()
		e.type = type_copy
		e.player_ref = _player
		e.is_elite = randf() < 0.1
		if "run_particles_enabled" in e:
			e.run_particles_enabled = false
		add_child.call_deferred(e)
		e.set_deferred("global_position", _random_pos_in_arena())
		call_deferred("_clear_enemy_drops", e)

func _random_pos_in_arena() -> Vector2:
	for _i in range(10):
		var p = Vector2(
			randf_range(_arena.position.x, _arena.end.x), 
			randf_range(_arena.position.y, _arena.end.y)
		)
		if _player == null or not is_instance_valid(_player) or p.distance_to(_player.global_position) > 180.0:
			return p
	return _arena.get_center()

func _clear_enemies() -> void :
	for e in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(e):
			e.queue_free()

func _clear_enemy_drops(enemy_node: Node) -> void :
	if not is_instance_valid(enemy_node):
		return
	if enemy_node.type != null and "drops" in enemy_node.type:
		enemy_node.type.drops.clear()
	for child in enemy_node.get_children():
		if "type" in child and child.type != null and "drops" in child.type:
			child.type.drops.clear()

func _contain_projectiles() -> void :
	var panel = get_parent() as Control
	if not panel:
		return
	var root = get_tree().current_scene
	var panel_rect = panel.get_global_rect()
	for node in root.get_children():
		if not is_instance_valid(node):
			continue
		if not (node is Node2D) or node is Control:
			continue
		if not panel_rect.has_point(node.global_position):
			node.queue_free()
			continue
		node.reparent(panel)

func _contain_enemies() -> void :
	for e in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(e):
			continue
		var pos = e.global_position
		var clamped = pos.clamp(_arena.position, _arena.end)
		if clamped != pos:
			e.global_position = clamped
