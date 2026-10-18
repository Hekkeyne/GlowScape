extends TextureButton
@export var hover_scale_x: float = 1.1
@export var anim_duration: float = 0.2

func _ready() -> void:
	await get_tree().process_frame
	pivot_offset = Vector2(0, size.y / 2)
	if $SFX and not $SFX.stream:
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav")

func _on_mouse_entered() -> void:
	var t := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale:x", hover_scale_x, anim_duration)
	t.tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), anim_duration + 0.05)
	$SFX.pitch_scale = randf_range(0.9, 1.1)
	$SFX.play()

func _on_mouse_exited() -> void:
	var t := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale:x", 1.0, anim_duration)
	t.tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), anim_duration + 0.05)
