extends TextureButton

@onready var name_label: Label = %NameLabel
@onready var players_label: Label = %PlayersLabel
@onready var lock_icon: TextureRect = %LockIcon

func setup(room: Dictionary) -> void :
	name_label.text = str(room.get("name", "???"))
	players_label.text = "%d/4" % int(room.get("players", 1))
	lock_icon.visible = bool(room.get("has_password", false))
	set_meta("room_idx", int(room.get("idx", -1)))

func set_selected(sel: bool) -> void :
	modulate = Color(1.25, 1.25, 1.25) if sel else Color.WHITE
