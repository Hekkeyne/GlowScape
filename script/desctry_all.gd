class_name RouletteVisual
extends Node2D

var sector_count: int = 8:
	set(v):
		sector_count = v
		_rebuild()
var radius: float = 1000.0
var base_rotation: float = 0.0
var line_progress: float = 0.0
var line_alpha: float = 1.0
var per_line_mode: bool = false
var overlap: float = 0.5
var start_line_progress: float = 0.0
var retract_progress: float = 0.0
var highlight_index: int = -1
var highlight_alpha: float = 0.18
var fade_speed: float = 10.0
var red_speed_mult: float = 3.0
var strike_index: int = -1
var strike_alpha: float = 0.0
var lit_sectors: PackedInt32Array = PackedInt32Array()
var lit_alpha: float = 0.18
var red_sectors: PackedInt32Array = PackedInt32Array()
var red_alpha: float = 0.0
var sweep_active: bool = false
var sweep_start: float = 0.0
var sweep_progress: float = 0.0
var sweep_alpha: float = 0.0
var fill_texture: Texture2D = null
var white_alphas: PackedFloat32Array = PackedFloat32Array()
var red_alphas: PackedFloat32Array = PackedFloat32Array()
var sector_radii: PackedFloat32Array = PackedFloat32Array()
var line_color: Color = Color(1, 1, 1, 0.5)
var highlight_color: Color = Color(1, 1, 1, 0.75)
var strike_color: Color = Color(1.0, 0.15, 0.15, 0.75)
func move_highlight(new_index: int) -> void:
	highlight_index = new_index
func clear_highlight() -> void:
	highlight_index = -1
func _rebuild() -> void:
	white_alphas.resize(sector_count)
	white_alphas.fill(0.0)
	red_alphas.resize(sector_count)
	red_alphas.fill(0.0)
	sector_radii.resize(sector_count)
	sector_radii.fill(0.0)

func _window_and_stagger() -> Array:
	var n = maxf(float(sector_count), 1.0)
	var ov = clampf(overlap, 0.0, 0.99)
	var denom = (n - 1.0) * (1.0 - ov) + 1.0
	var window = 1.0 / denom
	var stagger = window * (1.0 - ov)
	return [window, stagger]

func _local_p(i: int, t: float, window: float, stagger: float) -> float:
	return clampf((t - float(i) * stagger) / window, 0.0, 1.0)

func _smooth(x: float) -> float:
	var c = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

func _process(delta: float) -> void:
	if white_alphas.size() != sector_count:
		_rebuild()
	var smooth_w = 1.0 - exp(-fade_speed * delta)
	var smooth_r = 1.0 - exp(-fade_speed * red_speed_mult * delta)
	var changed := false
	for i in range(sector_count):
		var w_target := 0.0
		if i == highlight_index:
			w_target = highlight_alpha
		elif lit_sectors.has(i):
			w_target = lit_alpha
		var r_target := 0.0
		if i == strike_index:
			r_target = strike_alpha
		elif red_sectors.has(i):
			r_target = red_alpha
		var wc = white_alphas[i]
		if not is_equal_approx(wc, w_target):
			var nw = lerpf(wc, w_target, smooth_w)
			if absf(nw - w_target) < 0.004:
				nw = w_target
			white_alphas[i] = nw
			changed = true
		var rc = red_alphas[i]
		if not is_equal_approx(rc, r_target):
			var nr = lerpf(rc, r_target, smooth_r)
			if absf(nr - r_target) < 0.004:
				nr = r_target
			red_alphas[i] = nr
			changed = true
	if per_line_mode and sweep_active:
		var ws = _window_and_stagger()
		var window: float = ws[0]
		var stagger: float = ws[1]
		for i in range(sector_count):
			var grow = _smooth(_local_p(i, sweep_progress, window, stagger))
			var shrink = _smooth(_local_p(i, retract_progress, window, stagger))
			var r = grow * (1.0 - shrink)
			if i == 0 and sweep_progress < 0.001:
				r = maxf(r, start_line_progress)
			elif i == 0:
				r = maxf(r, start_line_progress)
			if not is_equal_approx(sector_radii[i], r):
				sector_radii[i] = r
				changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	var step = TAU / sector_count
	if sweep_active and sweep_alpha > 0.005:
		for i in range(sector_count):
			var r = sector_radii[i] * radius
			if r < 0.5:
				continue
			_draw_sector_pie(i, r, highlight_color, sweep_alpha)
	var la = line_color.a * line_alpha
	if la > 0.005:
		for i in range(sector_count):
			var f: float
			if per_line_mode:
				f = sector_radii[i]
				if i == 0 and sweep_progress < 0.001:
					f = start_line_progress
			else:
				f = line_progress
			if f <= 0.001:
				continue
			var a = base_rotation + sweep_start + i * step if per_line_mode else base_rotation + i * step
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * radius * f, Color(line_color.r, line_color.g, line_color.b, la), 1.5)
	for i in range(sector_count):
		if white_alphas[i] > 0.005:
			_draw_sector(i, highlight_color, white_alphas[i])
	for i in range(sector_count):
		if red_alphas[i] > 0.005:
			_draw_sector(i, strike_color, red_alphas[i])

func _draw_sector_pie(index: int, r: float, color: Color, alpha: float) -> void:
	var step = TAU / sector_count
	var a0 = base_rotation + sweep_start + index * step
	var a1 = a0 + step
	var pts = PackedVector2Array([Vector2.ZERO])
	var segments = 32
	for i in range(segments + 1):
		var a = lerpf(a0, a1, float(i) / float(segments))
		pts.append(Vector2(cos(a), sin(a)) * r)
	var col = Color(color.r, color.g, color.b, alpha)
	if fill_texture:
		var uvs = PackedVector2Array()
		for p in pts:
			uvs.append(Vector2(p.x / (radius * 2.0) + 0.5, p.y / (radius * 2.0) + 0.5))
		draw_polygon(pts, PackedColorArray([col]), uvs, fill_texture)
	else:
		draw_colored_polygon(pts, col)

func _draw_sector(index: int, color: Color, alpha: float) -> void:
	var step = TAU / sector_count
	var a0 = base_rotation + sweep_start + index * step if sweep_active else base_rotation + index * step
	var a1 = a0 + step
	var r = sector_radii[index] * radius if sweep_active else radius
	if r < 0.5:
		return
	var pts = PackedVector2Array([Vector2.ZERO])
	var segments = 32
	for i in range(segments + 1):
		var a = lerpf(a0, a1, float(i) / float(segments))
		pts.append(Vector2(cos(a), sin(a)) * r)
	var col = Color(color.r, color.g, color.b, alpha)
	if fill_texture:
		var uvs = PackedVector2Array()
		for p in pts:
			uvs.append(Vector2(p.x / (radius * 2.0) + 0.5, p.y / (radius * 2.0) + 0.5))
		draw_polygon(pts, PackedColorArray([col]), uvs, fill_texture)
	else:
		draw_colored_polygon(pts, col)
