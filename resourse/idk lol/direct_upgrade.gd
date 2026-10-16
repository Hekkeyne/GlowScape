extends Resource
class_name DirectUpgrade

@export var title: String = ""
@export var icon: Texture2D
@export var effect_value: float = 1.0
@export_enum("might", "area", "recovery", "armor", "movement_speed", "magnet", "growth", "luck", "max_health") var stat_type: String = "might"

func apply(player) -> void:
	if not is_instance_valid(player):
		return
	match stat_type:
		"might":
			player.might += effect_value
		"area":
			player.area += effect_value
		"recovery":
			player.recovery += effect_value
		"armor":
			player.armor += effect_value
		"movement_speed":
			player.movement_speed += effect_value
		"magnet":
			player.magnet += effect_value
		"growth":
			player.growth += effect_value
		"luck":
			player.luck += effect_value
		"max_health":
			player.max_health += effect_value
			player.health += effect_value

func stat_name_key() -> String:
	match stat_type:
		"might":
			return "STAT_MIGHT"
		"area":
			return "STAT_AREA"
		"recovery":
			return "STAT_RECOVERY"
		"armor":
			return "STAT_ARMOR"
		"movement_speed":
			return "STAT_MSPEED"
		"magnet":
			return "STAT_MAGNET"
		"growth":
			return "STAT_GROWTH"
		"luck":
			return "STAT_LUCK"
		"max_health":
			return "STAT_MHEALTH"
	return ""

func _format_value(value: float) -> String:
	if value == round(value):
		return str(int(value))
	return str(value)

func create_description() -> String:
	var result_text = ""
	if effect_value == 0:
		return result_text
	match stat_type:
		"max_health":
			result_text += tr("STAT_MHEALTH") % _format_value(effect_value) + "\n"
		"recovery":
			result_text += tr("STAT_RECOVERY") % _format_value(effect_value) + tr("PERSEC") + "\n"
		"armor":
			result_text += tr("STAT_ARMOR") % _format_value(effect_value) + "\n"
		"movement_speed":
			result_text += tr("STAT_MSPEED") % _format_value(effect_value) + "\n"
		"might":
			result_text += tr("STAT_MIGHT") % _format_value(effect_value * 100.0) + "\n"
		"area":
			result_text += tr("STAT_AREA") % _format_value(effect_value) + "\n"
		"magnet":
			result_text += tr("STAT_MAGNET") % _format_value(effect_value) + "\n"
		"growth":
			result_text += tr("STAT_GROWTH") % _format_value(effect_value * 100.0) + "\n"
		"luck":
			result_text += tr("STAT_LUCK") % _format_value(effect_value) + "\n"
	return result_text

func create_popup_text() -> String:
	var value_str: String = ""
	match stat_type:
		"might", "growth":
			value_str = _format_value(effect_value * 100.0)
		_:
			value_str = _format_value(effect_value)
	return tr(stat_name_key()) % value_str
