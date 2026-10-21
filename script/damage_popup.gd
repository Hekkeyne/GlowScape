extends Node2D

@export var pool_size: int = 30
var popup_scene: PackedScene = preload("res://scene/damage.tscn")
var _pool: Array[Label] = []
var _tweens: Dictionary = {}
var _cursor: int = 0

func _ready() -> void :
	z_index = 100
	for i in pool_size:
		var popup: Label = popup_scene.instantiate() as Label
		if popup == null:
			continue
		popup.hide()
		add_child(popup)
		_pool.append(popup)

func spawn(pos: Vector2, amount: float, is_crit: bool = false) -> void :
	if _pool.is_empty():
		return
	var popup: = _get_free_popup()
	if popup == null:
		popup = _pool[_cursor]
		_cursor = (_cursor + 1) % _pool.size()
	_play(popup, pos, amount, is_crit)

func _get_free_popup() -> Label:
	for i in _pool.size():
		var idx: int = (_cursor + i) % _pool.size()
		var popup: Label = _pool[idx]
		if is_instance_valid(popup) and not popup.visible:
			_cursor = (idx + 1) % _pool.size()
			return popup
	return null

func _play(popup: Label, pos: Vector2, amount: float, is_crit: bool) -> void :
	if not is_instance_valid(popup):
		return
	popup.text = str(int(amount)) if amount == round(amount) else "%.1f" % amount
	if is_crit:
		popup.add_theme_color_override("font_color", Color.RED)
	else:
		popup.remove_theme_color_override("font_color")
	popup.global_position = pos
	popup.scale = Vector2.ONE
	popup.modulate.a = 1.0
	popup.show()
	var old: Tween = _tweens.get(popup)
	if is_instance_valid(old):
		old.kill()
	var tw: Tween = create_tween()
	_tweens[popup] = tw
	tw.tween_property(popup, "scale", Vector2(2.0, 2.0), 0.1)
	tw.chain().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1)
	tw.chain().tween_property(popup, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(popup.hide)
