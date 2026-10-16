extends TextureButton

var is_changed = false
const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	var saved_locale = _load_locale()
	if saved_locale == "":
		saved_locale = OS.get_locale_language()
	_apply_locale(saved_locale)

func _apply_locale(locale: String) -> void:
	match locale:
		"ru":
			if has_node("Sprite2D"):
				$Sprite2D.texture = load("res://sprites/rus_lang.png")
			TranslationServer.set_locale("ru")
		_:
			if has_node("Sprite2D"):
				$Sprite2D.texture = load("res://sprites/eng_lang.png")
			TranslationServer.set_locale("en")

func _save_locale(locale: String) -> void:
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("language", "locale", locale)
	config.save(SAVE_PATH)

func _load_locale() -> String:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		return config.get_value("language", "locale", "")
	return ""

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

func _on_pressed() -> void:
	is_changed = true
	var current = TranslationServer.get_locale()
	var new_locale: String
	if current == "ru":
		new_locale = "en"
		if has_node("Sprite2D"):
			$Sprite2D.texture = load("res://sprites/eng_lang.png")
	else:
		new_locale = "ru"
		if has_node("Sprite2D"):
			$Sprite2D.texture = load("res://sprites/rus_lang.png")
			
	TranslationServer.set_locale(new_locale)
	_save_locale(new_locale)
