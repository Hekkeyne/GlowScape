extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	%cursor_animated_sprite.global_position = get_viewport().get_mouse_position()
