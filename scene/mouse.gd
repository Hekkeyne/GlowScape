extends CanvasLayer



func _ready() -> void :
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN



func _physics_process(_delta: float) -> void :
	%cursor_animated_sprite.global_position = get_viewport().get_mouse_position()
