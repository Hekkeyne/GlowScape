extends Node2D

const meta_path: String = "res://resourse/meta_stats/"
var meta_stats: Array = []
@onready var bonus_stats: Stats = Stats.new()
var character = null

func _ready() -> void :
	meta_stats = _load_meta()
	rebuild_bonus_stats()

func _load_meta() -> Array:
	var result: Array = []
	var dir = DirAccess.open(meta_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean = file_name.replace(".remap", "").replace(".import", "")
				if clean.ends_with(".tres"):
					var res = load(meta_path + clean)
					if res is MetaStat:
						result.append(res)
			file_name = dir.get_next()
	return result

func char_key(char) -> String:
	if char == null or not (char is Resource):
		return ""
	return char.resource_path

func _bonus_for(char) -> Stats:
	var s = Stats.new()
	var sd = get_node_or_null("/root/SaveData")
	var key = char_key(char)
	for meta in meta_stats:
		var lvl = sd.get_meta_level(key, meta.stat_type) if sd else 0
		var total = meta.effect_per_level * lvl
		match meta.stat_type:
			"max_health":
				s.max_health += total
			"recovery":
				s.recovery += total
			"armor":
				s.armor += total
			"movement_speed":
				s.movement_speed += total
			"might":
				s.might += total
			"area":
				s.area += total
			"magnet":
				s.magnet += total
			"growth":
				s.growth += total
			"luck":
				s.luck += total
	return s

func rebuild_bonus_stats(char = null) -> void :
	bonus_stats = _bonus_for(char if char != null else character)

func get_combined_stats(base: Stats, char = null) -> Stats:
	var b = _bonus_for(char if char != null else character)
	var s = Stats.new()
	s.max_health = base.max_health + b.max_health
	s.recovery = base.recovery + b.recovery
	s.armor = base.armor + b.armor
	s.movement_speed = base.movement_speed + b.movement_speed
	s.might = base.might + b.might
	s.area = base.area + b.area
	s.magnet = base.magnet + b.magnet
	s.growth = base.growth + b.growth
	s.luck = base.luck + b.luck
	return s

func gain_bonus_stats(player):
	rebuild_bonus_stats(character)
	player.max_health += bonus_stats.max_health
	player.recovery += bonus_stats.recovery
	player.armor += bonus_stats.armor
	player.movement_speed += bonus_stats.movement_speed
	player.might += bonus_stats.might
	player.area += bonus_stats.area
	player.magnet += bonus_stats.magnet
	player.growth += bonus_stats.growth
	player.luck += bonus_stats.luck
