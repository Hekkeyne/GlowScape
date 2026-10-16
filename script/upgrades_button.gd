extends TextureButton

@export var hover_scale: Vector2 = Vector2(1, 1.2)

func _ready() -> void:
	await get_tree().process_frame
	pivot_offset = size/2
	if $SFX and not $SFX.stream:
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav")

func _on_mouse_entered() -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", hover_scale, 0.2)
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()

func _on_mouse_exited() -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, 0.2)
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
