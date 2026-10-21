extends TextureButton

func _on_mouse_entered() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.stream = load("res://resourse/audio/idk_mouse.wav")
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()

func _ready() -> void :
	visible = false

func _on_mouse_exited() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)

func _physics_process(_delta: float) -> void :
	if get_tree().paused == true and owner.health <= 0 and visible == false:
		visible = true

func _on_pressed() -> void :
	get_tree().paused = false
	SaveData.microchips += owner.microchips
	SaveData.set_and_save()
	SceneChanger.change_scene("res://scene/main_menu.tscn")
