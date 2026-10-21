extends TextureButton
class_name DirectUpgradeSlot

@export var upgrade: DirectUpgrade:
	set(value):
		upgrade = value
		if value != null:
			$OptionSprite.texture = value.icon
			$OptionSprite2.texture = value.icon
			$Name.text = tr(value.title)
			$Description.text = value.create_description()
			$Label.text = tr("DIRECT_UPGRADE")
		else:
			$OptionSprite.texture = null
			$OptionSprite2.texture = null
			$Name.text = ""
			$Description.text = ""
			$Label.text = ""

func setup(upg: DirectUpgrade) -> void :
	upgrade = upg

func _on_gui_input(event: InputEvent) -> void :
	if event.is_action_pressed("click") and upgrade:
		$SFX.stream = load("res://resourse/audio/choose_upgrade.wav")
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			upgrade.apply(player)
		get_parent().close_option()

func _on_mouse_entered() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.stream = load("res://resourse/audio/idk_mouse.wav")
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()

func _on_mouse_exited() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
