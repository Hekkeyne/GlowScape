extends Control
var confirm_callbavk: Callable

func show_dialog(skill:Skill,callback:Callable)->void:
	confirm_callbavk=callback
	$NinePatchRect/VBoxContainer/Name.text=tr("UPGR_NAME") % [tr(skill.name), skill.level]
	$NinePatchRect/TextureRect.texture=skill.texture
	$NinePatchRect/VBoxContainer/Description.text=tr("UPGR_DESC")+skill.stats.create_description()
	$NinePatchRect/VBoxContainer/Cost.text = tr("UPGR_PRICE") % str(int(skill.cost))
	if skill.cost>SaveData.microchips:
		$NinePatchRect/Confirm.disabled=true
		$NinePatchRect/Confirm/Label.text = tr("NOTE")
	else:
		$NinePatchRect/Confirm.disabled=false

	show()

func _on_confirm_pressed() -> void:
	confirm_callbavk.call()
	hide()


func _on_decline_pressed() -> void:
	hide()
