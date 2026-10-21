extends TextureButton
var is_epilepsy: bool = false
const SAVE_PATH = "user://settings.cfg"
@export var ep_on: Texture2D
@export var ep_off: Texture2D
func _ready() -> void :
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	is_epilepsy = config.get_value("epi", "epilepsy", is_epilepsy)
	print("saved data ", is_epilepsy)
	_upgade_epi()



func _upgade_epi() -> void :
	$"../../FSkillTree/BackGround_Shader".visible = !is_epilepsy
	$"../../Menu/BackGround_Shader".visible = !is_epilepsy
	$"../../Beastiary/BackGround_Shader".visible = !is_epilepsy
	$"../../Weapon_select/BackGround_Shader".visible = !is_epilepsy
	$"../BackGround_Shader".visible = !is_epilepsy
	$"../../CharacterUpgrade/BackGround_Shader".visible = !is_epilepsy
	$"../../MultiplayerRoom/BackGround_Shader".visible = !is_epilepsy
	$"../../Multiplayer/BackGround_Shader".visible = !is_epilepsy
	$Sprite2D.texture = ep_off if is_epilepsy == false else ep_on

func _on_pressed() -> void :
	is_epilepsy = !is_epilepsy
	_upgade_epi()
	if has_node("SFX"):
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav")
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()
	save_config()

func save_config() -> void :
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("epi", "epilepsy", is_epilepsy)
	config.save(SAVE_PATH)
	print("saved data ", is_epilepsy)

func _on_mouse_entered() -> void :
	if has_node("NinePatchRect"):
		create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	if has_node("SFX"):
		$SFX.stream = load("res://resourse/audio/idk_mouse.wav")
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()

func _on_mouse_exited() -> void :
	if has_node("NinePatchRect"):
		create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
