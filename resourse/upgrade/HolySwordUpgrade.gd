extends Upgrade
class_name HolySwordUpgrade
@export var speed: float = 0.0
@export var amount: int = 0
func create_description() -> String:
	var rez: String = ""
	if damage != 0.0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0.0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if speed != 0.0:
		rez += tr("WEAPON_SPEED") % (int(speed) if speed == round(speed) else str(speed)) + "\n"
	if amount != 0:
		rez += tr("WEAPON_HOLY_SWORD_AMOUNT") % (int(amount) if amount == round(amount) else str(amount)) + "\n"
	return rez
