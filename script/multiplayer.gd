extends TextureButton
@export var hover_scale: Vector2 = Vector2(1, 1.1)
var is_scaled: bool = false

func _ready() -> void:
	pivot_offset=size
	if $SFX and not $SFX.stream:
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav")
	modulate=Color(1,1,1,0.5)

func _on_mouse_entered() -> void:
	if not disabled:
		create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()

func _on_mouse_exited() -> void:
	if not disabled:
		create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)

func _on_main_menu_off_play() -> void:
	if is_scaled:
		is_scaled = false
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, 0.2)
		modulate=Color(1,1,1,0.5)
		
func _on_character_on_play() -> void:
	if not is_scaled:
		is_scaled = true
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", hover_scale, 0.2)
		modulate=Color(1,1,1,1)
