extends Pickups
class_name Microchips

@export var microchips: int = 5
@export var texture: Texture2D = preload("res://sprites/microchips.png")
func activate():
	player_ref.gain_microchips(microchips)
