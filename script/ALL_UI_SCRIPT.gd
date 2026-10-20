extends CanvasLayer
const SAVE_PATH = "user://settings.cfg"
var buttonNORMAL:Texture2D=preload("res://sprites/mobile_tp_button.png")
var buttonnDISABLEd:Texture2D = preload("res://sprites/mobile_tp_button_disabled.png")
var character = Persistence.character
var can_tp = true

func _ready() -> void:
	var is_mobile = _check_is_mobile()
	if is_mobile:
		$Mouse.hide()
		_apply_handedness(_load_handedness())
	else:
		$Mouse.show()
		$NinePatchRectLEFT.hide()
		$NinePatchRectRIGHT.hide()
		$Control2/TextureButtonLEFT.hide()
		$Control/TextureButtonRIGHT.hide()
		

func _check_is_mobile() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return false

func _load_handedness() -> bool:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		return config.get_value("controls", "right_handed", true)
	return true

func _apply_handedness(is_right_handed: bool) -> void:
	$NinePatchRectRIGHT.visible = is_right_handed
	$Control/TextureButtonRIGHT.visible = is_right_handed
	$NinePatchRectLEFT.visible = not is_right_handed
	$Control2/TextureButtonLEFT.visible = not is_right_handed
	$Control/TextureButtonRIGHT.self_modulate=Color.from_string(character.color_trail, Color.WHITE)
	$Control2/TextureButtonLEFT.self_modulate = Color.from_string(character.color_trail, Color.WHITE)

func _on_dash_pressed(btn: TouchScreenButton) -> void:
	btn.get_node("colldown_tp").start()
	btn.texture_normal=buttonnDISABLEd
	$Control/TextureButtonRIGHT.self_modulate=Color.WHITE
	$Control2/TextureButtonLEFT.self_modulate = Color.WHITE

func _on_cooldown_timeout(btn: TouchScreenButton) -> void:
	btn.texture_normal=buttonNORMAL
	$Control/TextureButtonRIGHT.self_modulate=Color.from_string(character.color_trail, Color.WHITE)
	$Control2/TextureButtonLEFT.self_modulate = Color.from_string(character.color_trail, Color.WHITE)

func _on_texture_button_right_pressed() -> void:
	_on_dash_pressed($Control/TextureButtonRIGHT)

func _on_texture_button_left_pressed() -> void:
	_on_dash_pressed($Control2/TextureButtonLEFT)

func _on_colldown_tp_timeoutL() -> void:
	_on_cooldown_timeout($Control2/TextureButtonLEFT)

func _on_colldown_tp_timeoutR() -> void:
	_on_cooldown_timeout($Control/TextureButtonRIGHT)
