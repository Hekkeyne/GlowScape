extends Sprite2D

func _ready() -> void:
	region_enabled = true
	_update_region()
	get_viewport().size_changed.connect(_update_region)

func _update_region() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	region_rect = Rect2(0, 0, rect.size.x, rect.size.y)
	position = rect.position + rect.size / 2.0
