extends CanvasLayer

@onready var rect: ColorRect = $Trans_animation
@export var materian : Array[Material]

func change_scene(target_scene_path: String) -> void:
	get_tree().paused=true
	rect.visible = true
	rect.material=materian.pick_random()
	(rect.material as ShaderMaterial).set_shader_parameter("node_resolution", rect.size)
	$AudioStreamPlayer2D.play()
	await create_tween().tween_property(rect.material, "shader_parameter/factor", 1.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).finished
	get_tree().change_scene_to_file(target_scene_path)
	await create_tween().tween_property(rect.material, "shader_parameter/factor", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).finished
	rect.visible = false
	get_tree().paused = false
