extends Area2D
@export var sfx : Array[AudioStream]=[]
var direction : Vector2 = Vector2.RIGHT
var speed : float = 300
var damage: float = 1
var source 
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		if "might" in source:
			body.take_damage(damage*source.might)
		else:
			body.take_damage(damage)
		$virus_0.emitting=true
		$virus_1.emitting=true
		$AudioStreamPlayer2D.stream=sfx.pick_random()
		$AudioStreamPlayer2D.pitch_scale = randf_range(0.7,1.3)
		$AudioStreamPlayer2D.play()
		body.knockback = direction*75

func _physics_process(delta: float) -> void:
	global_position+= direction * speed * delta
	
func _ready() -> void:
	
	var player= get_tree().get_nodes_in_group("Player")
	if player.size()>0:
		look_at(player[0].global_position)
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().has_method("take_damage"):
		
		area.get_parent().take_damage(damage)
