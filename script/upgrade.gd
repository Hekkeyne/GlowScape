extends TextureButton

@export var skill : Skill
signal r_upgrade_confirm(upgrade:Skill, on_confirm:Callable)
var enabled : bool = false:
	set(value):
		enabled = value
		$PPpaa.show_behind_parent=value
		if value:
			$Outline.add_point((Vector2(0,0)))
			$Outline.add_point((Vector2(128,0)))
			$Outline.add_point((Vector2(128,128)))
			$Outline.add_point((Vector2(0,128)))
		if value and get_index()!=0:
			$Connection.add_point(Vector2(64,64)+initial_modifier())
			$Connection.add_point(get_parent().get_child(get_index()-1).position-position+Vector2(64,64)+final_modifier())

func _ready() -> void:
	if skill:
		texture_normal=skill.texture
		
func is_upgradable()-> bool:
	if get_index()==0:
		return true
	elif get_index()>0:
		if get_parent().get_child(get_index()-1).enabled == true:
			return true
		else:
			return false
	return false

func initial_modifier() -> Vector2:
	var difference = get_parent().get_child(get_index() - 1).position - position
	var modification : Vector2 = Vector2.ZERO
	if abs(difference.x) > abs(difference.y):
		if difference.x < 0:   modification.x = -64
		elif difference.x > 0: modification.x = 64
	else:
		if difference.y < 0:   modification.y = -64
		elif difference.y > 0: modification.y = 64
	return modification


func final_modifier() -> Vector2:
	var difference = get_parent().get_child(get_index() - 1).position - position
	var modification : Vector2 = Vector2.ZERO
	if abs(difference.x) > abs(difference.y):
		if difference.x < 0:   modification.x = 64
		elif difference.x > 0: modification.x = -64
	else:
		if difference.y < 0:   modification.y = 64
		elif difference.y > 0: modification.y = -64
	return modification

func _on_pressed() -> void:
	if is_upgradable() and not enabled : 
		r_upgrade_confirm.emit(skill,apply_upgrade)
	
func apply_upgrade()->void:
	SaveData.microchips -= skill.cost
	enabled = true
	get_parent().get_parent().set_skill_tree()
	get_parent().get_parent().get_total_stats()
