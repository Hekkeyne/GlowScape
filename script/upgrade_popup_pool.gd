extends Node2D
class_name UpgradePopupPool

@export var pool_size: int = 30
@export var rise_height: float = 45.0
@export var rise_time: float = 0.35
@export var hold_time: float = 1
@export var fade_time: float = 0.45
var popup_scene: PackedScene = preload("res://scene/damage.tscn")
var _pool: Array[Label] = []
var _tweens: Dictionary = {}
var _cursor: int = 0

func _ready() -> void :
	z_index = 100
	add_to_group("UpgradePopupPool")
	for i in pool_size:
		var popup: Label = popup_scene.instantiate() as Label
		if popup == null:
			continue
		popup.hide()
		add_child(popup)
		_pool.append(popup)

func spawn(pos: Vector2, text: String, color: Color = Color.WHITE) -> void :
	if _pool.is_empty():
		return
	var popup: = _get_free_popup()
	if popup == null:
		popup = _pool[_cursor]
		_cursor = (_cursor + 1) % _pool.size()
	_play(popup, pos, text, color)

func _get_free_popup() -> Label:
	for i in _pool.size():
		var idx: int = (_cursor + i) % _pool.size()
		var popup: Label = _pool[idx]
		if is_instance_valid(popup) and not popup.visible:
			_cursor = (idx + 1) % _pool.size()
			return popup
	return null

func _play(popup: Label, pos: Vector2, text: String, color: Color) -> void :
	if not is_instance_valid(popup):
		return
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.reset_size()
	popup.global_position = pos - popup.size * 0.5
	popup.scale = Vector2.ONE
	popup.modulate.a = 1.0
	popup.show()
	var old: Tween = _tweens.get(popup)
	if is_instance_valid(old):
		old.kill()
	var tw: Tween = create_tween()
	_tweens[popup] = tw
	tw.tween_property(popup, "global_position", pos - popup.size * 0.5 + Vector2(0.0, - rise_height), rise_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(hold_time)
	tw.chain().tween_property(popup, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(popup.hide)
