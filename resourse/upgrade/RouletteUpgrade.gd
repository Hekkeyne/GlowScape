extends Upgrade
class_name RouletteUpgrade
@export var speed: float
@export_range(-6, 0) var sectors: int = 0

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if speed != 0:
		rez += tr("WEAPON_SPEED") % (int(speed) if speed == round(speed) else str(speed)) + "\n"
	if sectors != 0:
		rez += tr("WEAPON_SECTORS") % (int(sectors) if sectors == round(sectors) else str(sectors)) + "\n"
	return rez
