extends Upgrade
class_name BlackHoleUpgrade

@export_range(0, 2) var holes: int = 0
@export_range(0, 300, 5) var radius: float = 0
@export_range(0, 3, 0.25) var duration: float = 0
@export_range(0, 300, 10) var pull: float = 0
@export_range(0, 500, 25) var knock: float = 0

func create_description():
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if holes != 0:
		rez += tr("BH_HOLES") % (int(holes) if holes == round(holes) else str(holes)) + "\n"
	if radius != 0:
		rez += tr("BH_RADIUS") % (int(radius) if radius == round(radius) else str(radius)) + "\n"
	if duration != 0:
		rez += tr("BH_DURATION") % (int(duration) if duration == round(duration) else str(duration)) + "\n"
	if pull != 0:
		rez += tr("BH_PULL") % (int(pull) if pull == round(pull) else str(pull)) + "\n"
	if knock != 0:
		rez += tr("BH_KNOCK") % (int(knock) if knock == round(knock) else str(knock)) + "\n"
	return rez
