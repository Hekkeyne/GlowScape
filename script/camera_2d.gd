extends Camera2D

@export var landscape_zoom: float = 1.0
@export var portrait_zoom: float = 1.8
@export var shake_decay: float = 1.8
@export var shake_amplitude: float = 24.0
@export var shake_frequency: float = 18.0

var _trauma: float = 0.0
var _shake_base_offset: Vector2 = Vector2.ZERO

func _ready() -> void :
	_apply()
	get_window().size_changed.connect(_apply)
	_adjust_zoom()
	_shake_base_offset = offset

func _process(delta: float) -> void :
	_shake_process(delta)

func _apply() -> void :
	var s: Vector2i = get_window().size
	var z: float = portrait_zoom if s.y > s.x else landscape_zoom
	zoom = Vector2(z, z)

func _adjust_zoom() -> void :
	var w: Window = get_window()
	var target_zoom: float = portrait_zoom if w.size.y > w.size.x else landscape_zoom
	create_tween().tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.3)

func add_screen_shake(amount: float) -> void :
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func set_shake_base_offset(new_offset: Vector2) -> void :
	_shake_base_offset = new_offset

func _shake_process(delta: float) -> void :
	if _trauma <= 0.0:
		if offset != _shake_base_offset:
			offset = _shake_base_offset
		return
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var power: float = _trauma * _trauma
	var t: float = Time.get_ticks_msec() * 0.001 * shake_frequency
	var n1: Vector2 = Vector2(sin(t * 1.7), cos(t * 2.3))
	var n2: Vector2 = Vector2(sin(t * 3.1 + 1.7), cos(t * 2.9 + 0.4))
	var noise: Vector2 = n1 + n2 * 0.35
	if noise.length_squared() > 0.0001:
		noise = noise.normalized()
	else:
		noise = Vector2.RIGHT
	offset = _shake_base_offset + noise * power * shake_amplitude
