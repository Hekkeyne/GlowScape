extends HSlider

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.05
	value = SaveData.get_volume()
	value_changed.connect(_on_value_changed)

func _on_value_changed(v: float) -> void:
	SaveData.set_volume(v)
