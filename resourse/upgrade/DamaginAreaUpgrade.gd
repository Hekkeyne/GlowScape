extends Upgrade
class_name DamaginAreaUpgrade
@export var area: float

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if area != 0:
		rez += tr("WEAPON_AREA") % (int(area) if area == round(area) else str(area)) + "\n"
	return rez
