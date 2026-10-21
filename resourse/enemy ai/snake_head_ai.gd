class_name SnakeHeadAI
extends EnemyAIBehavior

@export_range(1, 20) var segments_count: int = 5
@export_range(20.0, 100.0, 5.0) var segment_spacing: float = 30.0
@export var segment_scene: PackedScene
@export var segment_type: Enemy
@export_range(100.0, 2000.0, 50.0) var chase_range: float = 1100.0
@export_range(0.0, 1.0, 0.05) var wiggle_amplitude: float = 0.5
@export_range(1.0, 20.0, 0.5) var wiggle_frequency: float = 6.0
@export_range(0.5, 3.0, 0.1) var segment_smooth_speed: float = 1.5

var time: float = 0.0
var segments: Array[EnemyBase] = []

func on_spawn(enemy: CharacterBody2D, player: Node2D) -> void :
	var head = enemy as EnemyBase
	if not head or not segment_scene or segments_count <= 0:
		return
	var actual_count = randi_range(1, segments_count)
	if head.is_elite:
		actual_count *= 2
	var back_direction: = Vector2.LEFT
	if is_instance_valid(player):
		back_direction = (head.global_position - player.global_position).normalized()
	var previous: EnemyBase = head
	for i in range(actual_count):
		var segment: EnemyBase = segment_scene.instantiate()
		segment.type = segment_type
		segment.global_position = previous.global_position + back_direction * segment_spacing
		segment.is_segment = true
		head.get_tree().current_scene.add_child(segment)
		segment.player_ref = player
		segment.knockback = Vector2.ZERO
		_setup_segment_leader.call_deferred(segment, previous, segment_spacing)
		segments.append(segment)
		previous = segment
	head.enemy_died.connect(_on_head_died)
	time = randf() * TAU

func _setup_segment_leader(segment: EnemyBase, previous: EnemyBase, spacing: float) -> void :
	if not is_instance_valid(segment):
		return
	if previous.ai is SnakeSegmentAI:
		var prev_ai: SnakeSegmentAI = previous.ai
		prev_ai.follower = segment
	if segment.ai is SnakeSegmentAI:
		var seg_ai: SnakeSegmentAI = segment.ai
		seg_ai.leader = previous
		seg_ai.follow_distance = spacing
		seg_ai.smooth_speed = segment_smooth_speed
	elif segment.type and segment.type.ai_behavior is SnakeSegmentAI:
		segment.ai = segment.type.ai_behavior.duplicate()
		var seg_ai: SnakeSegmentAI = segment.ai
		seg_ai.leader = previous
		seg_ai.follow_distance = spacing
		seg_ai.smooth_speed = segment_smooth_speed

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var head = enemy as EnemyBase
	if not head or not player or not is_instance_valid(player):
		return Vector2.ZERO
	var direction = player.global_position - head.global_position
	var distance = direction.length()
	direction = direction.normalized()
	if head.has_method("set_separation"):
		head.set_separation(distance)
	if distance > chase_range and not head.is_elite:
		head.queue_free()
		for seg in segments:
			if is_instance_valid(seg):
				seg.queue_free()
		return Vector2.ZERO
	time += delta
	var wiggle = sin(time * wiggle_frequency) * wiggle_amplitude
	var move_direction = (direction + Vector2( - direction.y, direction.x) * wiggle).normalized()
	return move_direction * head.speed

func _on_head_died(_head: EnemyBase) -> void :
	for seg in segments:
		if is_instance_valid(seg) and not seg.is_dying:
			seg.die()
