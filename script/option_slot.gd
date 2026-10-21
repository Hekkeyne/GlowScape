extends TextureButton
var is_new: bool = false
@export var item: Item:
	set(value):
		item = value
		if value.upgrades.size() > 0 and value.upgrades.size() + 1 != value.level:
			$OptionSprite.texture = value.icon
			$OptionSprite2.texture = value.icon
			$Name.text = value.title
			if is_new:
				$Label.text = tr("NEW_ITEM_TEXT")
				if value is Weapon:
					$Description.text = value.description
				else:
					$Description.text = value.upgrades[value.level - 1].create_description()
			else:
				$Label.text = tr("LEVEL_OPTION_SLOT") % str(item.level + 1) + "/" + str(item.upgrades.size() + 1)
				$Description.text = value.upgrades[value.level - 1].create_description()
		else:
			$OptionSprite.texture = value.evolution.icon
			$OptionSprite2.texture = value.evolution.icon
			$Label.text = ""
			$Name.text = value.title
			$Description.text = tr("EVOLUTION_LABEL")

func _ready() -> void :
	pass

func _on_gui_input(event: InputEvent) -> void :
	if event.is_action_pressed("click") and item:
		$SFX.stream = load("res://resourse/audio/choose_upgrade.wav")
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.play()
		if not get_parent().check_item(item):
			item.upgrade_item()
		elif item is PassiveItem:
			item.upgrade_item()
		get_parent().close_option()



func _on_mouse_entered() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(2, 2, 2, 2), 0.25)
	$SFX.stream = load("res://resourse/audio/idk_mouse.wav")
	$SFX.pitch_scale = randf_range(0.7, 1.3)
	$SFX.play()


func _on_mouse_exited() -> void :
	create_tween().tween_property($NinePatchRect, "modulate", Color(1, 1, 1, 1), 0.25)
