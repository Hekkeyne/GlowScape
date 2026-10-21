extends Node2D

var microchips = 0
var skill_tree = []
var meta_levels = {}

const PATH = "user://player_data.cfg"

@onready var config = ConfigFile.new()

func _ready() -> void :
	load_data()
	apply_volume()

func save_data() -> void :
	config.save(PATH)

func set_data() -> void :
	config.set_value("Player", "microchips", microchips)
	config.set_value("Player", "skill_tree", skill_tree)
	config.set_value("Player", "meta_levels", meta_levels)

func set_and_save() -> void :
	set_data()
	save_data()

func load_data() -> void :
	if config.load(PATH) != OK:
		set_and_save()
	microchips = config.get_value("Player", "microchips", 0)
	var raw_tree = config.get_value("Player", "skill_tree", [])
	if raw_tree == null:
		raw_tree = []
	skill_tree = raw_tree
	var raw_meta = config.get_value("Player", "meta_levels", {})
	if raw_meta == null or raw_meta is Array:
		raw_meta = {}
	meta_levels = raw_meta

func get_meta_level(char_key: String, stat_type: String) -> int:
	if meta_levels.has(char_key) and meta_levels[char_key] is Dictionary:
		return int(meta_levels[char_key].get(stat_type, 0))
	return 0

func meta_total_level(char_key: String) -> int:
	var total = 0
	if meta_levels.has(char_key) and meta_levels[char_key] is Dictionary:
		for stat_type in meta_levels[char_key]:
			total += int(meta_levels[char_key][stat_type])
	return total

func buy_meta_level(char_key: String, stat_type: String, cost: int) -> bool:
	if microchips < cost:
		return false
	microchips -= cost
	if not meta_levels.has(char_key) or not (meta_levels[char_key] is Dictionary):
		meta_levels[char_key] = {}
	meta_levels[char_key][stat_type] = get_meta_level(char_key, stat_type) + 1
	set_and_save()
	return true

func refund_meta_level(char_key: String, stat_type: String, refund: int) -> void :
	var lvl = get_meta_level(char_key, stat_type)
	if lvl <= 0:
		return
	meta_levels[char_key][stat_type] = lvl - 1
	microchips += refund
	set_and_save()

func reset_meta(char_key: String) -> void :
	var sum = _refund_sum(char_key)
	meta_levels[char_key] = {}
	microchips += sum
	set_and_save()

func _refund_sum(char_key: String) -> int:
	var sum = 0
	for meta in Persistence.meta_stats:
		var lvl = get_meta_level(char_key, meta.stat_type)
		for l in range(lvl):
			sum += meta.cost_at(l)
	return sum

func get_volume() -> float:
	return config.get_value("Settings", "volume", 1.0)

func set_volume(value: float) -> void :
	config.set_value("Settings", "volume", value)
	save_data()
	apply_volume()

func apply_volume() -> void :
	var bus: = AudioServer.get_bus_index("Master")
	if bus > -1:
		var v: = clampf(get_volume(), 0.0, 1.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(v) if v > 0.001 else -80.0)
