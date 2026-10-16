extends Resource
class_name MetaStat

@export_enum("might", "area", "recovery", "armor", "movement_speed", "magnet", "growth", "luck", "max_health") var stat_type: String = "might"
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(1, 20) var max_level: int = 5
@export var base_cost: int = 30
@export var cost_step: int = 20
@export var effect_per_level: float = 0.05
@export_range(0, 30) var unlock_at_total: int = 0

func cost_at(level: int) -> int:
	return base_cost + cost_step * level

func stat_name_key() -> String:
	match stat_type:
		"might":
			return "META_MIGHT"
		"area":
			return "META_AREA"
		"recovery":
			return "META_RECOVERY"
		"armor":
			return "META_ARMOR"
		"movement_speed":
			return "META_MSPEED"
		"magnet":
			return "META_MAGNET"
		"growth":
			return "META_GROWTH"
		"luck":
			return "META_LUCK"
		"max_health":
			return "META_MHEALTH"
	return ""

func _fmt(v: float) -> String:
	return str(int(v)) if v == round(v) else str(v)

func value_text() -> String:
	var sign = "+" if effect_per_level >= 0 else ""
	match stat_type:
		"might", "growth":
			return sign + _fmt(effect_per_level * 100.0)
		_:
			return sign + _fmt(effect_per_level)

func display_text() -> String:
	var key = display_name if display_name != "" else stat_name_key()
	return tr(key) % value_text()

func per_level_text() -> String:
	return display_text()
