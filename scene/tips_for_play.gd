extends CanvasItem

@export var show_time: float = 8.0
@export var fade_time: float = 1.0

func _ready() -> void :
	var is_mobile_tip = name == "MOBILE_TIP"
	if is_mobile_tip != _check_is_mobile():
		visible = false
		queue_free()
		return
	for child in get_children():
		if child is AnimatedSprite2D:
			child.stop()
			child.frame = 0
			child.frame_progress = 0.0
			child.play("default")
	var tw = create_tween()
	tw.tween_interval(show_time)
	tw.tween_property(self, "modulate:a", 0.0, fade_time)
	tw.tween_callback(queue_free)

func _check_is_mobile() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return false
