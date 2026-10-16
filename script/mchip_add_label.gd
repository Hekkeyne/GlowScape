extends Label

func _ready() -> void:
	pop()

func pop():
	var tween = get_tree().create_tween()
	tween.chain().tween_property(self, "scale", Vector2(1, 1), 0.1)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	var fade_tween = get_tree().create_tween().set_parallel(true)
	fade_tween.tween_property(self, "global_position:y", global_position.y - 60, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.5)
	await fade_tween.finished
	queue_free()
