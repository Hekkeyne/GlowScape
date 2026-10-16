extends TextureButton

const SAVE_PATH = "user://settings.cfg"
var is_right_handed: bool = true

func _ready() -> void:
	visible = _check_is_mobile()
	_load_handedness()
	_apply_handedness()

func _check_is_mobile() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return false

func _load_handedness() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		is_right_handed = config.get_value("controls", "right_handed", true)
	else:
		is_right_handed = true

func _save_handedness() -> void:
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("controls", "right_handed", is_right_handed)
	config.save(SAVE_PATH)

func _apply_handedness() -> void:
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = not is_right_handed

func _on_pressed() -> void:
	is_right_handed = not is_right_handed
	_apply_handedness()
	_save_handedness()
	if has_node("SFX"):
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav") 
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()

func _on_mouse_entered() -> void:
	if has_node("NinePatchRect"):
		create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	if has_node("SFX"):
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav") 
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()

func _on_mouse_exited() -> void:
	if has_node("NinePatchRect"):
		create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
