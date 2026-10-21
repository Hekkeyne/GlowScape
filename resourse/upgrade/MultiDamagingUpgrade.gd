extends Upgrade
class_name MultiDamagingUpgrade

@export var amount: int
@export var speed: float
@export var area: float


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
	if area != 0:
		rez += tr("WEAPON_AREA") % (int(area) if area == round(area) else str(area)) + "\n"
	return rez
