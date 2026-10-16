extends Upgrade
class_name CircularUpgrade


@export var angular_speed:float
@export var amount:int 

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if angular_speed != 0:
		rez += tr("WEAPON_ANG_SPEED") % (int(angular_speed) if angular_speed == round(angular_speed) else str(angular_speed)) + "\n"
	if amount != 0:
		rez += tr("WEAPON_AMOUNT") % (int(amount) if amount == round(amount) else str(amount)) + "\n"
	return rez
