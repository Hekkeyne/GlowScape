extends Node

@onready var master_bus_index: int = AudioServer.get_bus_index("Master")
var visibility_callback: JavaScriptObject

func _ready() -> void:
	if OS.has_feature("web"):
		setup_web_focus_filter()

func setup_web_focus_filter() -> void:
	visibility_callback = JavaScriptBridge.create_callback(_on_web_visibility_changed)
	var document = JavaScriptBridge.get_interface("document")
	if document:
		document.addEventListener("visibilitychange", visibility_callback)

func _on_web_visibility_changed(_args: Array) -> void:
	var document = JavaScriptBridge.get_interface("document")
	if not document:
		return
	var is_hidden: bool = document.hidden
	AudioServer.set_bus_mute(master_bus_index, is_hidden)
