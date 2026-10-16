extends CanvasLayer
func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		hide()
	else: 
		show()
		Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
func _physics_process(_delta: float) -> void:
	%cursor_animated_sprite.global_position = get_viewport().get_mouse_position()
