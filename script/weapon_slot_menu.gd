extends Panel

var icon = null:
	set(value):
		icon = value
		$TextureButton.texture_normal = value

signal pressed

func _ready():
	$Select.hide()

func _on_texture_button_pressed():
	for slot in get_parent().get_children():
		slot.deselect()
	$Select.show()
	pressed.emit()

func deselect():
	$Select.hide()

func select():
	$Select.show()

func _on_texture_button_mouse_entered() -> void :
	create_tween().tween_property($TextureButton, "scale", Vector2(1.05, 1.05), 0.1)
	$TextureButton / Particles.emitting = true

func _on_texture_button_mouse_exited() -> void :
	create_tween().tween_property($TextureButton, "scale", Vector2(1, 1), 0.1)
	$TextureButton / Particles.emitting = false
