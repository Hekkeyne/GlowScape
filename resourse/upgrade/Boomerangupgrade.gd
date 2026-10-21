extends Upgrade
class_name BoomerangUpgrade

@export var amount: int
@export var speed: float
@export var return_speed: float
@export var max_distance: float

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if speed != 0:
		rez += tr("WEAPON_SPEED") % (int(speed) if speed == round(speed) else str(speed)) + "\n"
	if amount != 0:
		rez += tr("WEAPON_AMOUNT") % (int(amount) if amount == round(amount) else str(amount)) + "\n"
	if return_speed != 0:
		rez += tr("WEAPON_RETURN_SPEED") % (int(return_speed) if return_speed == round(return_speed) else str(return_speed)) + "\n"
	if max_distance != 0:
		rez += tr("WEAPON_MAX_DISTANCE") % (int(max_distance) if max_distance == round(max_distance) else str(max_distance)) + "\n"
	return rez
