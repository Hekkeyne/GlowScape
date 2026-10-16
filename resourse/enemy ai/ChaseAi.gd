class_name ChaseAI
extends EnemyAIBehavior
@export_range(50.0, 2000.0, 50.0) var chase_range: float = 1100.0
@export_range(20.0, 200.0, 10.0) var attack_range: float = 50.0
@export var stop_when_close: bool = false
func calculate_movement(enemy: CharacterBody2D, player: Node2D, _delta: float) -> Vector2:
	if not player or not is_instance_valid(player):
		return Vector2.ZERO
	var direction = (player.global_position - enemy.global_position)
	var distance = direction.length()
	direction = direction.normalized()
	if enemy.has_method("set_separation"):
		enemy.set_separation(distance)
	if distance > chase_range and not enemy.is_elite:
		enemy.queue_free()
		return Vector2.ZERO
	if stop_when_close and distance <= attack_range:
		return Vector2.ZERO
	return direction * enemy.speed
