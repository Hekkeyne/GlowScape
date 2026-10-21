extends Panel

signal start_requested()
signal leave_requested()

@export var chat_font: Font
@export var chat_font_size: int = 16
@export var sys_color_join: Color = Color(0.55, 1.0, 0.55)
@export var sys_color_leave: Color = Color(0.7, 0.7, 0.7)
@export var sys_color_kick: Color = Color(1.0, 0.45, 0.35)

@onready var title_label: Label = %RoomTitle
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_list: VBoxContainer = %ChatList
@onready var chat_input: LineEdit = %ChatInput
@onready var send_btn: TextureButton = %SendButton
@onready var start_btn: TextureButton = %StartButton
@onready var leave_btn: TextureButton = %LeaveButton

var _slots: Array = []
var _icons: Array = []
var _names: Array = []
var _kicks: Array = []
var _slot_ids: Array = []

func _ready() -> void :
	for i in range(1, 5):
		var idx = str(i)
		var slot: Control = _pick(null, "%Slot" + idx, "Slot" + idx)
		_slots.append(slot)
		_icons.append(_pick(slot, "%Icon" + idx, "Icon" + idx))
		_names.append(_pick(slot, "%Name" + idx, "Name" + idx))
		var kick: TextureButton = _pick(slot, "%Kick" + idx, "Kick" + idx)
		_kicks.append(kick)
		if kick != null and not kick.pressed.is_connected(_on_kick_pressed.bind(i - 1)):
			kick.pressed.connect(_on_kick_pressed.bind(i - 1))
	send_btn.pressed.connect(_on_send_pressed)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.placeholder_text = tr("CHAT_PLACEHOLDER")
	if chat_font != null:
		chat_input.add_theme_font_override("font", chat_font)
	chat_input.add_theme_font_size_override("font_size", chat_font_size)
	start_btn.pressed.connect(_on_start_pressed)
	leave_btn.pressed.connect(_on_leave_pressed)
	Net.peer_joined.connect(_on_roster_joined)
	Net.peer_left.connect(_on_roster_left)
	Net.peer_departed.connect(_on_peer_departed)
	Net.peer_kicked.connect(_on_peer_kicked)
	Net.kicked.connect(_on_self_kicked)
	Net.chat_message.connect(_on_chat_message)
	Net.chat_history_received.connect(_on_history)
	refresh()

func reset_view() -> void :
	for c in chat_list.get_children():
		c.queue_free()
	_slot_ids.clear()
	chat_input.text = ""
	refresh()

func _pick(slot: Node, unique_name: String, plain_name: String) -> Node:
	var n = get_node_or_null(unique_name)
	if n == null and slot != null:
		n = slot.get_node_or_null(plain_name)
	return n

func refresh() -> void :
	if title_label != null:
		title_label.text = Net.room_name if Net.room_name != "" else tr("MULTIPLAYER_TITLE")
	if start_btn != null:
		start_btn.visible = Net.is_host
	_slot_ids.clear()
	var ids: Array = Net.peer_names.keys()
	ids.sort()
	for i in range(4):
		var slot: Control = _slots[i]
		var icon: TextureRect = _icons[i]
		var nm: Label = _names[i]
		var kick: TextureButton = _kicks[i]
		if slot == null:
			_slot_ids.append(-1)
			continue
		if i < ids.size():
			var id = ids[i]
			_slot_ids.append(id)
			var chars: Dictionary = Net.peer_chars.get(id, {})
			var icon_path = str(chars.get("icon", ""))
			if icon_path == "":
				icon_path = str(chars.get("tex", ""))
			if icon != null:
				if icon_path != "" and ResourceLoader.exists(icon_path):
					icon.texture = load(icon_path)
				else:
					icon.texture = null
			if nm != null:
				nm.text = str(Net.peer_names.get(id, "?"))
			slot.modulate.a = 1.0
			if kick != null:
				kick.visible = Net.is_host and id != multiplayer.get_unique_id()
		else:
			_slot_ids.append(-1)
			if icon != null:
				icon.texture = null
			if nm != null:
				nm.text = tr("EMPTY_SLOT_LABEL")
			slot.modulate.a = 0.35
			if kick != null:
				kick.visible = false

func _on_roster_joined(_id: int, pname: String) -> void :
	refresh()
	_sys(tr("SYS_JOIN") % pname, sys_color_join)

func _on_roster_left(_id: int) -> void :
	refresh()

func _on_peer_departed(_id: int, pname: String) -> void :
	_sys(tr("SYS_LEAVE") % pname, sys_color_leave)

func _on_peer_kicked(_id: int, pname: String) -> void :
	_sys(tr("SYS_KICKED") % pname, sys_color_kick)

func _on_self_kicked() -> void :
	_sys(tr("SYS_YOU_KICKED"), sys_color_kick)

func _on_history(history: Array) -> void :
	for c in chat_list.get_children():
		c.queue_free()
	for entry in history:
		_append_line("%s: %s" % [str(entry.get("sender", "?")), str(entry.get("text", ""))], Color.WHITE)

func _on_kick_pressed(slot_index: int) -> void :
	if not Net.is_host:
		return
	if slot_index < 0 or slot_index >= _slot_ids.size():
		return
	var id = _slot_ids[slot_index]
	if id < 0:
		return
	Net.kick_player(id)

func _on_start_pressed() -> void :
	start_requested.emit()

func _on_leave_pressed() -> void :
	leave_requested.emit()

func _on_send_pressed() -> void :
	_send_chat()

func _on_chat_submitted(_text: String) -> void :
	_send_chat()

func _send_chat() -> void :
	var t = chat_input.text
	chat_input.text = ""
	Net.send_chat(t)
	chat_input.grab_focus()

func _on_chat_message(sender: String, text: String) -> void :
	_append_line("%s: %s" % [sender, text], Color.WHITE)

func _sys(text: String, color: Color) -> void :
	_append_line(text, color)

func _append_line(text: String, color: Color) -> void :
	var line = Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", color)
	if chat_font != null:
		line.add_theme_font_override("font", chat_font)
	line.add_theme_font_size_override("font_size", chat_font_size)
	chat_list.add_child(line)
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)
