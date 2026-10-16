extends TextureButton

func _ready() -> void:
	var os_name = OS.get_name()
	var is_mobile = os_name == "Android" or os_name == "iOS"
	visible = is_mobile 

func _on_mouse_entered() -> void:
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.stream = load("res://resourse/audio/idk_mouse.wav") 
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()

func _on_mouse_exited() -> void:
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
func _on_pressed() -> void:
	var current_orientation = DisplayServer.screen_get_orientation()
	if current_orientation == DisplayServer.SCREEN_PORTRAIT or current_orientation == DisplayServer.SCREEN_REVERSE_PORTRAIT:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
