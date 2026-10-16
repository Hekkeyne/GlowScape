extends Panel

signal stats_changed

@export var char_grid: GridContainer
@export var rows_root: Control
const STAT_TYPES = ["might", "area", "recovery", "armor", "movement_speed", "magnet", "growth", "luck", "max_health"]
var current_char: Character = null
var fmt_num = func(v: float) -> String:
	return str(int(v)) if v == round(v) else str(v)

func _ready() -> void:
	if char_grid:
		char_grid.character_selected.connect(set_character)
	_connect_rows()
	visibility_changed.connect(_on_visibility_changed)
	if char_grid and char_grid.characters.size() > 0:
		set_character(char_grid.characters[0])

func _on_visibility_changed() -> void:
	if visible:
		refresh()

func _connect_rows() -> void:
	if rows_root == null:
		return
	for st in STAT_TYPES:
		var row = rows_root.get_node_or_null("Row_" + st)
		if row == null:
			continue
		var plus = _find_child(row, "Plus")
		if plus == null:
			continue
		plus.pressed.connect(_on_plus.bind(st))

func _find_child(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_child(child, node_name)
		if found != null:
			return found
	return null

func set_character(c: Character) -> void:
	current_char = c
	refresh()

func _meta_for(stat_type: String) -> MetaStat:
	for m in Persistence.meta_stats:
		if m.stat_type == stat_type:
			return m
	return null

func _on_plus(stat_type: String) -> void:
	var meta = _meta_for(stat_type)
	if meta == null or current_char == null:
		return
	var sd = get_node("/root/SaveData")
	var key = Persistence.char_key(current_char)
	var lvl = sd.get_meta_level(key, stat_type)
	if lvl >= meta.max_level:
		return
	if sd.meta_total_level(key) < meta.unlock_at_total:
		return
	if sd.buy_meta_level(key, stat_type, meta.cost_at(lvl)):
		refresh()
		stats_changed.emit()

func _on_reset_pressed() -> void:
	if current_char == null:
		return
	get_node("/root/SaveData").reset_meta(Persistence.char_key(current_char))
	refresh()
	stats_changed.emit()

func refresh() -> void:
	var sd = get_node("/root/SaveData")
	var chips = get_node_or_null("ChipsLabel")
	if chips == null:
		chips = get_node_or_null("Chips")
	if chips:
		chips.text = tr("TR_CHIPS") % fmt_num.call(sd.microchips)
	if current_char == null or rows_root == null:
		return
	var key = Persistence.char_key(current_char)
	$Panel/CurrentCharacter.texture=current_char.icon
	for st in STAT_TYPES:
		var row = rows_root.get_node_or_null("Row_" + st)
		if row == null:
			continue
		var meta = _meta_for(st)
		if meta == null:
			continue
		var lvl = sd.get_meta_level(key, st)
		var locked = sd.meta_total_level(key) < meta.unlock_at_total
		var name_label = _find_child(row, "NameLabel")
		var level_label = _find_child(row, "LevelLabel")
		var cost_label = _find_child(row, "CostLabel")
		var plus = _find_child(row, "Plus")
		if name_label:
			name_label.text = meta.per_level_text()
		if level_label:
			level_label.text = " " + tr("META_LEVEL") % [lvl, meta.max_level]
		if cost_label:
			if lvl >= meta.max_level:
				cost_label.text = tr("META_MAXED")
			elif locked:
				cost_label.text = tr("META_LOCKED") % str(meta.unlock_at_total)
			else:
				cost_label.text = " " + tr("META_COST") % fmt_num.call(meta.cost_at(lvl))
		if plus:
			plus.disabled = locked or lvl >= meta.max_level or sd.microchips < meta.cost_at(lvl)
	_highlight_grid()

func _highlight_grid() -> void:
	if char_grid == null:
		return
	for child in char_grid.get_children():
		if child.has_method("deselect"):
			child.deselect()
	var idx = char_grid.characters.find(current_char)
	if idx == -1 or idx >= char_grid.get_child_count():
		return
	var slot = char_grid.get_child(idx)
	if slot.has_method("select"):
		slot.select()
