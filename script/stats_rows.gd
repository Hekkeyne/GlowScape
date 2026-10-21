extends VBoxContainer

const STAT_ORDER = ["max_health", "recovery", "armor", "movement_speed", "might", "area", "magnet", "growth", "luck"]

var fmt_num = func(v: float) -> String:
	return str(int(v)) if v == round(v) else str(v)

func show_stats(stats: Stats) -> void :
	for st in STAT_ORDER:
		var row = get_node_or_null("Row_" + st)
		if row == null:
			continue
		var name_label = row.get_node_or_null("NameLabel")
		var value_label = row.get_node_or_null("ValueLabel")
		var value = _value_of(stats, st) if stats != null else 0.0
		if stats == null or value == 0:
			row.hide()
			continue
		row.show()
		if name_label:
			name_label.text = tr(_name_key(st)).replace("%s", "")
		if value_label:
			value_label.text = _value_text(st, value)

func _name_key(st: String) -> String:
	match st:
		"max_health":
			return "PLAYER_MHEALTH"
		"recovery":
			return "META_RECOVERY"
		"armor":
			return "PLAYER_ARMOR"
		"movement_speed":
			return "PLAYER_MSPEED"
		"might":
			return "PLAYER_MIGHT"
		"area":
			return "PLAYER_AREA"
		"magnet":
			return "PLAYER_MAGNET"
		"growth":
			return "PLAYER_GROWTH"
		"luck":
			return "PLAYER_LUCK"
	return ""

func _value_of(stats: Stats, st: String) -> float:
	match st:
		"max_health":
			return stats.max_health
		"recovery":
			return stats.recovery
		"armor":
			return stats.armor
		"movement_speed":
			return stats.movement_speed
		"might":
			return stats.might
		"area":
			return stats.area
		"magnet":
			return stats.magnet
		"growth":
			return stats.growth
		"luck":
			return stats.luck
	return 0.0

func _value_text(st: String, value: float) -> String:
	match st:
		"might", "growth":
			return fmt_num.call(value * 100) + "%"
		"recovery":
			return fmt_num.call(value) + tr("PERSEC")
		_:
			return fmt_num.call(value)
