extends GridContainer

@export var character_slot: PackedScene
@onready var starting_weapon = %StartingWeapon
signal on_play

@export var characters: Array[Character]

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
	if character.starting_weapon != null and character.starting_weapon.resource_path != "":
		character.starting_weapon = ResourceLoader.load(character.starting_weapon.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	Persistence.character = character
	starting_weapon.texture = character.starting_weapon.icon
	$"../../../TitleStartingWeapon".text=character.starting_weapon.title
	%StatsRows.show_stats(Persistence.get_combined_stats(character.base_stats, character))
	%Play.disabled = false
	%Multiplayer.disabled=false
	emit_signal("on_play")
	%Play/Label.text = "M_START2"
