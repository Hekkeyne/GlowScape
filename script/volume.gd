extends TextureButton

var off_vol_texture: Texture2D = preload("res://sprites/volume_off.png")
var on_vol_texture: Texture2D = preload("res://sprites/volume.png")
var last_volume: float = 0

func _ready() -> void :
	$SFX.stream = load("res://resourse/audio/idk_mouse.wav")

func _physics_process(delta: float) -> void :
	if SaveData.get_volume() <= 0:
		$Sprite2D.texture = off_vol_texture
	else:
		$Sprite2D.texture = on_vol_texture

func _on_pressed() -> void :
	if SaveData.get_volume() != -80.0:
		last_volume = SaveData.get_volume()
		$Sprite2D.texture = off_vol_texture
		SaveData.config.set_value("Settings", "volume", -80.0)
		SaveData.save_data()
		SaveData.apply_volume()
		print(SaveData.get_volume())
	else:
		$Sprite2D.texture = on_vol_texture
		SaveData.config.set_value("Settings", "volume", last_volume)
		SaveData.save_data()
		SaveData.apply_volume()
		print(SaveData.get_volume())

func _on_mouse_entered() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()

func _on_mouse_exited() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
