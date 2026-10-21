extends TextureButton

func _on_mouse_entered() -> void :
	create_tween().tween_property($Button_Texture, "modulate", Color(2, 2, 2, 2), 0.25)

func _on_mouse_exited() -> void :
	create_tween().tween_property($Button_Texture, "modulate", Color(1, 1, 1, 1), 0.25)
