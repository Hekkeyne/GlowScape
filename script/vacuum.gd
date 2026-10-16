extends Pickups

class_name Vacuum
func activate():
	super.activate()
	player_ref.get_tree().call_group("pickup","follow",player_ref,true)
