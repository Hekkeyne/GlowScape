extends GridContainer
@export var character_slot: PackedScene
@export var characters: Array[Character]
signal character_selected(character: Character)

func _ready():
	load_characters()

func load_characters():
	for child in get_children():
		child.queue_free()
	for character in characters:
		var slot = character_slot.instantiate()
		slot.icon = character.icon
		slot.pressed.connect(_on_pressed.bind(character))
		add_child(slot)

func _on_pressed(character: Character):
	emit_signal("character_selected", character)
