extends Parallax2D
const TILE_SIZE: float = 32.0

func _ready() -> void :
	get_viewport().size_changed.connect(_update_parallax_size)
	_update_parallax_size()

func _update_parallax_size() -> void :
	var viewport_size: Vector2 = get_viewport_rect().size
	var new_w: float = ceil(viewport_size.x / TILE_SIZE) * TILE_SIZE
	var new_h: float = ceil(viewport_size.y / TILE_SIZE) * TILE_SIZE
	var final_size: Vector2 = Vector2(new_w, new_h)
	$grundsquare.region_rect.size = final_size
	repeat_size = final_size
	$grundsquare.position = viewport_size / 2
