extends Resource
class_name Stats

@export var max_health: float
@export var recovery: float
@export var armor: float
@export var movement_speed: float
@export var might: float
@export var area: float
@export var magnet: float
@export var growth: float
@export var luck: float
@export_multiline var description: String

func create_description():
	var result_text = ""
	if max_health != 0:
		result_text += tr("STAT_MHEALTH") % (int(max_health) if max_health == round(max_health) else str(max_health)) + "\n"
	if recovery != 0:
		result_text += tr("STAT_RECOVERY") % (int(recovery) if recovery == round(recovery) else str(recovery)) + tr("PERSEC") + "\n"
	if armor != 0:
		result_text += tr("STAT_ARMOR") % (int(armor) if armor == round(armor) else str(armor)) + "\n"
	if movement_speed != 0:
		result_text += tr("STAT_MSPEED") % (int(movement_speed) if movement_speed == round(movement_speed) else str(movement_speed)) + "\n"
	if might != 0:
		result_text += tr("STAT_MIGHT") % (int(might * 100) if might * 100 == round(might * 100) else str(might * 100)) + "\n"
	if area != 0:
		result_text += tr("STAT_AREA") % (int(area) if area == round(area) else str(area)) + "\n"
	if magnet != 0:
		result_text += tr("STAT_MAGNET") % (int(magnet) if magnet == round(magnet) else str(magnet)) + "\n"
	if growth != 0:
		result_text += tr("STAT_GROWTH") % (int(growth * 100) if growth * 100 == round(growth * 100) else str(growth * 100)) + "\n"
	if luck != 0:
		result_text += tr("STAT_LUCK") % (int(luck) if luck == round(luck) else str(luck)) + "\n"
	return result_text

func create_player_description():
	var result_text = ""
	if max_health != 0:
		result_text += tr("PLAYER_MHEALTH") % (int(max_health) if max_health == round(max_health) else str(max_health)) + "\n"
	if recovery != 0:
		result_text += tr("PLAYER_RECOVERY") % (int(recovery) if recovery == round(recovery) else str(recovery)) + tr("PERSEC") + "\n"
	if armor != 0:
		result_text += tr("PLAYER_ARMOR") % (int(armor) if armor == round(armor) else str(armor)) + "\n"
	if movement_speed != 0:
		result_text += tr("PLAYER_MSPEED") % (int(movement_speed) if movement_speed == round(movement_speed) else str(movement_speed)) + "\n"
	if might != 0:
		result_text += tr("PLAYER_MIGHT") % (int(might * 100) if might * 100 == round(might * 100) else str(might * 100)) + "%" + "\n"
	if area != 0:
		result_text += tr("PLAYER_AREA") % (int(area) if area == round(area) else str(area)) + "\n"
	if magnet != 0:
		result_text += tr("PLAYER_MAGNET") % (int(magnet) if magnet == round(magnet) else str(magnet)) + "\n"
	if growth != 0:
		result_text += tr("PLAYER_GROWTH") % (int(growth * 100) if growth * 100 == round(growth * 100) else str(growth * 100)) + "%" + "\n"
	if luck != 0:
		result_text += tr("PLAYER_LUCK") % (int(luck) if luck == round(luck) else str(luck)) + "\n"
	return result_text
