extends Label


func _physics_process(_delta: float) -> void:
	text = tr("TR_CHIPS") % (int(SaveData.microchips))
