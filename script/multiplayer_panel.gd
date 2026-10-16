extends Panel

signal refresh_requested()
signal create_requested(room_name: String, password: String)
signal connect_requested(room: Dictionary, password: String)
signal direct_join_requested(ip: String, password: String)

@export var room_row_scene: PackedScene
@export var bottom_up: bool = true
@export_range(0.0, 1.0, 0.05) var dim_alpha: float = 0.25

var _rooms: Array = []
var _rows: Array = []
var _selected: int = -1
var _connecting: bool = false
var _dots_timer: float = 0.0
var _dots_count: int = 0

@onready var title_label: Label = %Title
@onready var name_field: LineEdit = %NameField
@onready var save_name_btn: TextureButton = %SaveNameButton
@onready var room_list: VBoxContainer = %RoomList
@onready var refresh_btn: TextureButton = %RefreshButton
@onready var room_name_field: LineEdit = %RoomNameField
@onready var create_btn: TextureButton = %CreateButton
@onready var create_password_field: LineEdit = %CreatePasswordField
@onready var no_password_check: CheckBox = %NoPasswordCheck
@onready var password_field: LineEdit = %PasswordField
@onready var direct_ip_field: LineEdit = %DirectIPField
@onready var connect_btn: TextureButton = %ConnectButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	title_label.text = tr("MULTIPLAYER_TITLE")
	no_password_check.text = tr("NO_PASSWORD_LABEL")
	name_field.text = Net.player_name
	room_name_field.placeholder_text = tr("ROOM_NAME_PLACEHOLDER")
	direct_ip_field.placeholder_text = tr("IP_PLACEHOLDER")
	no_password_check.button_pressed = true
	refresh_btn.pressed.connect(_on_refresh_pressed)
	create_btn.pressed.connect(_on_create_pressed)
	connect_btn.pressed.connect(_on_connect_pressed)
	save_name_btn.pressed.connect(_on_save_name_pressed)
	no_password_check.toggled.connect(_on_no_password_toggled)
	direct_ip_field.text_changed.connect(_on_direct_ip_changed)
	clear_status()
	_refresh_visibility()

func _process(delta: float) -> void:
	if not _connecting:
		return
	_dots_timer += delta
	if _dots_timer >= 0.35:
		_dots_timer = 0.0
		_dots_count = (_dots_count % 3) + 1
		status_label.text = tr("CONNECTING_LABEL") + ".".repeat(_dots_count)

func _in_room() -> bool:
	return Net.session_active

func _need_password() -> bool:
	if _selected < 0 or _selected >= _rooms.size():
		return false
	return bool(_rooms[_selected].get("has_password", false))

func _has_direct_ip() -> bool:
	return direct_ip_field.text.strip_edges() != ""

func _set_btn(btn: BaseButton, enabled: bool) -> void:
	btn.disabled = not enabled
	btn.modulate.a = dim_alpha if not enabled else 1.0

func _set_line(line: LineEdit, enabled: bool) -> void:
	line.editable = enabled
	line.modulate.a = dim_alpha if not enabled else 1.0
	line.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _refresh_visibility() -> void:
	var in_room = _in_room()
	var idle = not in_room and not _connecting
	var need_pass = _need_password()
	var direct_ip = _has_direct_ip()
	_set_btn(refresh_btn, idle)
	_set_btn(create_btn, idle)
	_set_btn(save_name_btn, not in_room)
	_set_btn(no_password_check, not in_room)
	_set_btn(connect_btn, (direct_ip or need_pass) and idle)
	_set_line(name_field, not in_room)
	_set_line(room_name_field, not in_room)
	_set_line(direct_ip_field, idle)
	_set_line(password_field, (need_pass or direct_ip) and idle)
	_set_line(create_password_field, (not no_password_check.button_pressed) and not in_room)

func _on_direct_ip_changed(_t: String) -> void:
	_refresh_visibility()

func _on_save_name_pressed() -> void:
	var n = name_field.text.strip_edges()
	if n == "":
		n = "Player"
	Net.save_name(n)
	name_field.text = n
	set_ok_text(tr("NAME_SAVED_LABEL") + " " + n)

func _on_no_password_toggled(_button_pressed: bool) -> void:
	_refresh_visibility()

func set_rooms(rooms: Array) -> void:
	_rooms = rooms
	_selected = -1
	_rebuild_rows()
	_refresh_visibility()

func _rebuild_rows() -> void:
	_clear_list()
	if room_row_scene == null:
		return
	var order := range(_rooms.size())
	if bottom_up:
		order.reverse()
	for idx in order:
		var row = room_row_scene.instantiate()
		room_list.add_child(row)
		row.setup(_rooms[idx])
		row.pressed.connect(_on_row_pressed.bind(idx))
		_rows.append(row)
	if _rooms.is_empty():
		set_info_text(tr("NO_ROOMS_LABEL"))
	else:
		clear_status()

func _clear_list() -> void:
	for row in _rows:
		if is_instance_valid(row):
			row.queue_free()
	_rows.clear()

func _on_row_pressed(index: int) -> void:
	if _connecting or _in_room():
		return
	_selected = index
	for r in range(_rows.size()):
		if is_instance_valid(_rows[r]):
			var real_idx = _rows[r].get_meta("room_idx", -1)
			_rows[r].set_selected(real_idx == index)
	_refresh_visibility()
	if _need_password():
		password_field.text = ""
		password_field.grab_focus()
	else:
		_request_connect(_rooms[index], "")

func _on_connect_pressed() -> void:
	if _connecting or _in_room():
		return
	var ip = direct_ip_field.text.strip_edges()
	if ip != "":
		if not Net.is_valid_ip(ip):
			set_status_text(tr("IP_ERROR_LABEL"))
			return
		_request_direct(ip, password_field.text)
		return
	if _selected < 0 or _selected >= _rooms.size():
		return
	if not _need_password():
		return
	_request_connect(_rooms[_selected], password_field.text)

func _request_connect(room: Dictionary, password: String) -> void:
	_connecting = true
	_dots_count = 1
	_dots_timer = 0.0
	status_label.remove_theme_color_override("font_color")
	status_label.text = tr("CONNECTING_LABEL") + "."
	connect_requested.emit(room, password)

func _request_direct(ip: String, password: String) -> void:
	_connecting = true
	_dots_count = 1
	_dots_timer = 0.0
	status_label.remove_theme_color_override("font_color")
	status_label.text = tr("CONNECTING_LABEL") + "."
	direct_join_requested.emit(ip, password)

func _on_refresh_pressed() -> void:
	if _connecting or _in_room():
		return
	_selected = -1
	for r in range(_rows.size()):
		if is_instance_valid(_rows[r]):
			_rows[r].set_selected(false)
	clear_status()
	_refresh_visibility()
	refresh_requested.emit()

func _on_create_pressed() -> void:
	if _connecting or _in_room():
		return
	_selected = -1
	for r in range(_rows.size()):
		if is_instance_valid(_rows[r]):
			_rows[r].set_selected(false)
	clear_status()
	_refresh_visibility()
	var rname = room_name_field.text.strip_edges()
	if rname == "":
		rname = tr("ROOM_NAME_DEFAULT") % Net.player_name
	var password := ""
	if not no_password_check.button_pressed:
		password = create_password_field.text
	create_requested.emit(rname, password)

func set_status_busy(text: String) -> void:
	_connecting = true
	_dots_count = 1
	_dots_timer = 0.0
	status_label.remove_theme_color_override("font_color")
	status_label.text = text + "."

func set_status_text(text: String) -> void:
	_connecting = false
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))

func set_ok_text(text: String) -> void:
	_connecting = false
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))

func set_info_text(text: String) -> void:
	_connecting = false
	status_label.text = text
	status_label.remove_theme_color_override("font_color")

func clear_status() -> void:
	_connecting = false
	status_label.text = ""
	status_label.remove_theme_color_override("font_color")
