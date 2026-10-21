extends Upgrade
class_name TurretUpgrade
@export var amount: int

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if amount != 0:
		rez += tr("WEAPON_AMOUNT") % (int(amount) if amount == round(amount) else str(amount)) + "\n"
	return rez
