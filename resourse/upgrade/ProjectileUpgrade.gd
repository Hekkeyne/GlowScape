extends Upgrade
class_name ProjectileUpgrade
@export var speed: float

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if speed != 0:
		rez += tr("WEAPON_SPEED") % (int(speed) if speed == round(speed) else str(speed)) + "\n"
	return rez
