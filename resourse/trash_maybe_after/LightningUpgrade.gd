extends Upgrade
class_name LightningUpgrade

@export var amount: int

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % str(damage) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % str(cooldown) + "\n"
	if amount != 0:
		rez += tr("WEAPON_AMOUNT") % str(amount) + "\n"
	return rez
