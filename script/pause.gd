extends Control


func _on_pause_pressed() -> void:
	get_tree().paused=true
	%Resume.show()
	%Quit.show()
	$Pause.hide()
	$Panel.show()


func _on_resume_pressed() -> void:
	get_tree().paused=false
	%Resume.hide()
	%Quit.hide()
	$Pause.show()
	$Panel.hide()


func _on_quit_pressed() -> void:
	%Quit.hide()
	%Resume.hide()
	%quit_no.show()
	%quit_yes.show()


func _on_quit_no_pressed() -> void:
	%Quit.show()
	%Resume.show()
	%quit_no.hide()
	%quit_yes.hide()

func _on_quit_yes_pressed() -> void:
	SaveData.microchips+=owner.microchips
	SaveData.set_and_save()
	SceneChanger.change_scene("res://scene/main_menu.tscn")
