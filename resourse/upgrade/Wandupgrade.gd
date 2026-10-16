extends Upgrade
class_name LaserUpgrade

@export_range(0, 4) var reflections: int = 0
@export_range(0, 2) var lasers: int = 0
func create_description() -> String:
	var rez = ""
	if damage != 0:
		rez += tr("WEAPON_DAMAGE") % (int(damage) if damage == round(damage) else str(damage)) + "\n"
	if cooldown != 0:
		rez += tr("WEAPON_COOLDOWN") % (int(cooldown) if cooldown == round(cooldown) else str(cooldown)) + "\n"
	if reflections != 0:
		rez += tr("LASER_REFLECTIONS") % (int(reflections) if reflections == round(reflections) else str(reflections)) + "\n"
	if lasers != 0:
		rez += tr("LASER_EMITTERS") % (int(lasers) if lasers == round(lasers) else str(lasers)) + "\n"
	return rez
