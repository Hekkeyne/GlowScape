class_name EnemyAIBehavior
extends Resource

func calculate_movement(_enemy: CharacterBody2D, _player: Node2D, _delta: float) -> Vector2:
	return Vector2.ZERO
func on_spawn(_enemy: CharacterBody2D, _player: Node2D) -> void :
	pass
func on_death(_enemy: CharacterBody2D) -> void :
	pass
