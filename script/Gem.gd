extends Pickups
class_name Gem

@export var XP: float
func activate():
	super.activate()
	player_ref.gain_XP(XP)
