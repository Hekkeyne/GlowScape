extends TextureButton

func _ready() -> void :
	if $SFX and not $SFX.stream:
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav")

func _on_mouse_entered() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()

func _on_mouse_exited() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
