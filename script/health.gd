extends Pickups
class_name Health

@export var amount: float = 20

func activate():
	super.activate()
	player_ref.health += amount
