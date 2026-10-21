class_name SnakeSegmentAI
extends EnemyAIBehavior

@export var follow_distance: float = 30.0
@export_range(0.5, 10.0, 0.1) var smooth_speed: float = 1.5

var leader: EnemyBase
var follower: EnemyBase

func on_death(_enemy: CharacterBody2D) -> void :
	if is_instance_valid(follower) and follower.ai is SnakeSegmentAI:
		var follower_ai: SnakeSegmentAI = follower.ai
		if is_instance_valid(leader):
			follower_ai.leader = leader
		else:
			follower_ai.leader = null

func calculate_movement(enemy: CharacterBody2D, player: Node2D, _delta: float) -> Vector2:
	var segment = enemy as EnemyBase
	if not segment:
		return Vector2.ZERO
	if not is_instance_valid(leader) or leader.is_dying:
		return Vector2.ZERO
	var direction = leader.global_position - segment.global_position
	var distance = direction.length()
	if distance <= follow_distance:
		return Vector2.ZERO
	var over_dist = distance - follow_distance
	var smooth_factor = clampf(over_dist / 50.0, 0.1, 1.0) * smooth_speed
	return direction.normalized() * segment.speed * smooth_factor
