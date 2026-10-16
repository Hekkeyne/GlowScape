extends ColorRect

func _ready() -> void:
	_update_shader_size()
	item_rect_changed.connect(_update_shader_size)

func _update_shader_size() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("u_rect_size", size)
