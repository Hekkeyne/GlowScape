extends GridContainer
 
const path = "res://resourse/enemy/"
const weapon_path = "res://resourse/weapon/"
const weapon_evo_path = "res://resourse/weapon upgrade/"
var custom_font = load("res://sprites/PublicPixel.ttf")
var enemies = []
var weapons = []
var weapon_evos = []
var button_texture = preload("res://sprites/button_ui.png") 
var style_normal : StyleBoxTexture
var style_hover : StyleBoxTexture
var style_pressed : StyleBoxTexture
var equal_texture : Texture2D = preload("res://sprites/wheelspin_arrow.png")
var plus_texture:Texture2D=preload("res://sprites/plus_texture.png")
func _ready():
	create_custom_styles()
	dir_contents()
	
func dir_contents():
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				file_name = dir.get_next()
				continue
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var actual_file_name = file_name.trim_suffix(".remap")
				var full_path = path + actual_file_name
				var enemy_resource = load(full_path) as Enemy
				if enemy_resource:
					enemies.append(enemy_resource)
					var button = Button.new()
					button.mouse_filter=Control.MOUSE_FILTER_PASS
					button.add_theme_font_override("font", custom_font)
					button.add_theme_font_size_override("font_size", 35)
					button.icon = enemy_resource.icon
					button.custom_minimum_size=Vector2(250,250)
					button.expand_icon=true
					button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
					button.add_theme_stylebox_override("normal", style_normal)
					button.add_theme_stylebox_override("hover", style_hover)
					button.add_theme_stylebox_override("pressed", style_pressed)
					button.add_theme_color_override("font_color", Color("ff0000"))
					button.add_theme_color_override("font_hover_color", Color("9b9b9b")) 
					button.add_theme_color_override("font_pressed_color", Color("aaaaaa")) 
					button.pressed.connect(_on_pressed.bind("enemy", button))
					add_child(button)
			file_name = dir.get_next()
		dir.list_dir_end()
	var weapon_dir = DirAccess.open(weapon_path)
	if weapon_dir:
		weapon_dir.list_dir_begin()
		var weapon_file_name = weapon_dir.get_next()
		while weapon_file_name != "":
			if weapon_dir.current_is_dir():
				weapon_file_name = weapon_dir.get_next()
				continue
			if weapon_file_name.ends_with(".tres") or weapon_file_name.ends_with(".tres.remap"):
				var actual_file_name = weapon_file_name.trim_suffix(".remap")
				var full_path = weapon_path + actual_file_name
				var weapon_resource = load(full_path) as Weapon
				if weapon_resource:
					weapons.append(weapon_resource)
					var button = Button.new()
					button.mouse_filter=Control.MOUSE_FILTER_PASS
					button.add_theme_font_override("font", custom_font)
					button.add_theme_font_size_override("font_size", 35)
					button.icon = weapon_resource.icon
					button.custom_minimum_size=Vector2(250,250)
					button.expand_icon=true
					button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
					button.add_theme_stylebox_override("normal", style_normal)
					button.add_theme_stylebox_override("hover", style_hover)
					button.add_theme_stylebox_override("pressed", style_pressed)
					button.add_theme_color_override("font_color", Color("FFFFFF"))
					button.add_theme_color_override("font_hover_color", Color("9b9b9b")) 
					button.add_theme_color_override("font_pressed_color", Color("aaaaaa")) 
					button.pressed.connect(_on_pressed.bind("weapon", button))
					add_child(button)
			weapon_file_name = weapon_dir.get_next()
		weapon_dir.list_dir_end()
	var weapon_evo_dir = DirAccess.open(weapon_evo_path)
	if weapon_evo_dir:
		weapon_evo_dir.list_dir_begin()
		var weapon_evo_file_name = weapon_evo_dir.get_next()
		while weapon_evo_file_name != "":
			if weapon_evo_dir.current_is_dir():
				weapon_evo_file_name = weapon_evo_dir.get_next()
				continue
			if weapon_evo_file_name.ends_with(".tres") or weapon_evo_file_name.ends_with(".tres.remap"):
				var actual_file_name = weapon_evo_file_name.trim_suffix(".remap")
				var full_path = weapon_evo_path + actual_file_name
				var weapon_evo_resource = load(full_path) as Weapon
				if weapon_evo_resource:
					weapon_evos.append(weapon_evo_resource)
					var button = Button.new()
					button.mouse_filter=Control.MOUSE_FILTER_PASS
					button.add_theme_font_override("font", custom_font)
					button.add_theme_font_size_override("font_size", 35)
					button.icon = weapon_evo_resource.icon
					button.custom_minimum_size=Vector2(250,250)
					button.expand_icon=true
					button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
					button.add_theme_stylebox_override("normal", style_normal)
					button.add_theme_stylebox_override("hover", style_hover)
					button.add_theme_stylebox_override("pressed", style_pressed)
					button.add_theme_color_override("font_color", Color("36f1fb"))
					button.add_theme_color_override("font_hover_color", Color("9b9b9b")) 
					button.add_theme_color_override("font_pressed_color", Color("aaaaaa")) 
					button.pressed.connect(_on_pressed.bind("weapon_evo", button))
					add_child(button)
			weapon_evo_file_name = weapon_evo_dir.get_next()
		weapon_evo_dir.list_dir_end()

func _on_pressed(type: String, button: Button):
	if type == "enemy":
		var index = button.get_index()
		%Arrow.visible=false
		%Arrow2.visible=false
		%UpgradeTexture.visible=false
		%UpgradeTexture2.visible=false
		%Name.text = tr("BEAST_NAME") % tr(enemies[index].title)
		%Health.text = tr("BEAST_HEALTH") % (int(enemies[index].health) if enemies[index].health == round(enemies[index].health) else enemies[index].health)
		%Damage.text = tr("BEAST_DAMAGE") % (int(enemies[index].damage) if enemies[index].damage == round(enemies[index].damage) else enemies[index].damage)
		%Description.text = tr(str(enemies[index].description))
		%TextureEnemy.texture = enemies[index].icon
		%Information.show()
	elif type == "weapon":
		var index = button.get_index() - enemies.size()
		%Arrow.visible=true
		%Arrow.texture=plus_texture
		%Arrow2.visible=true
		%Arrow2.texture=equal_texture
		%UpgradeTexture.visible=true
		%UpgradeTexture.texture = weapons[index].item_needed.icon
		%UpgradeTexture2.visible=true
		%UpgradeTexture2.texture = weapons[index].evolution.icon
		%Name.text = ""
		%Damage.text = ""
		%Health.text = tr(str(weapons[index].title))
		%Description.text = tr(str(weapons[index].description))
		%TextureEnemy.texture = weapons[index].icon
		%Information.show()
	elif type == "weapon_evo":
		var index = button.get_index() - enemies.size() - weapons.size()
		%Name.text =""
		%Arrow.visible=true
		%Arrow.texture=equal_texture
		%Arrow2.visible=true
		%Arrow2.texture=plus_texture
		%UpgradeTexture.visible=true
		%UpgradeTexture.texture=weapon_evos[index].before_evolution
		%UpgradeTexture2.visible=true
		%UpgradeTexture2.texture=weapon_evos[index].before_item_needed
		%Damage.text = ""
		%Health.text =  tr(str(weapon_evos[index].title))
		%Description.text = tr(str(weapon_evos[index].description))
		%TextureEnemy.texture = weapon_evos[index].icon
		%Information.show()

func create_custom_styles():
	var margin_size = 4
	style_normal = StyleBoxTexture.new()
	style_normal.texture = button_texture
	style_normal.texture_margin_left = margin_size
	style_normal.texture_margin_top = margin_size
	style_normal.texture_margin_right = margin_size
	style_normal.texture_margin_bottom = margin_size
	style_normal.modulate_color = Color(1.0, 1.0, 1.0, 0.6)
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8
	style_normal.content_margin_left = 1
	style_normal.content_margin_right = 1
	style_hover = style_normal.duplicate()
	style_hover.modulate_color = Color(1.3, 1.3, 1.3, 1.0) 
	style_pressed = style_normal.duplicate()
	style_pressed.modulate_color = Color(0.7, 0.7, 0.7, 0.8)
	style_normal.content_margin_top = 16
	style_normal.content_margin_bottom = 16
