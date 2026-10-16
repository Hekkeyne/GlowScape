extends Camera2D

@export var landscape_zoom: float = 1.0
@export var portrait_zoom: float = 1.8

func _ready() -> void:
	_apply()
	get_window().size_changed.connect(_apply)
	_adjust_zoom

func _apply() -> void:
	var s := get_window().size
	var z := portrait_zoom if s.y > s.x else landscape_zoom
	zoom = Vector2(z, z)

func _adjust_zoom() -> void:
	var w := get_window()
	var target_zoom: float
	if w.size.y > w.size.x:
		target_zoom = portrait_zoom
	else:
		target_zoom =landscape_zoom
	
	create_tween().tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.3)
