extends Upgrade
class_name VortexUpgrade

@export var max_enemies: int = 0
@export var speed_bonus: float = 0.0
@export var lifetime: float = 0.0
@export var amount: int = 0

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if max_enemies != 0:
		rez += tr("VORTEX_MAX_ENEMIES") % (int(max_enemies) if max_enemies == round(max_enemies) else str(max_enemies)) + "\n"
	if speed_bonus != 0:
		rez += tr("VORTEX_SPEED_BONUS") % (int(speed_bonus) if speed_bonus == round(speed_bonus) else str(speed_bonus)) + "\n"
	if lifetime != 0:
		rez += tr("VORTEX_LIFETIME") % (int(lifetime) if lifetime == round(lifetime) else str(lifetime)) + "\n"
	if amount != 0:
		rez += tr("VORTEX_AMOUNT") % (int(amount) if amount == round(amount) else str(amount)) + "\n"
	return rez
