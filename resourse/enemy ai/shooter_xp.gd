class_name GemShooterAI
extends EnemyAIBehavior

@export_range(50.0, 400.0, 10.0) var search_radius: float = 250.0
@export_range(10.0, 60.0, 5.0) var pickup_range: float = 35.0
@export_range(0.5, 5.0, 0.5) var shoot_cooldown: float = 2.0
@export_range(0.1, 1.0, 0.1) var xp_multiplier: float = 0.5
@export var throw_speed: float = 450.0
@export_range(0.3, 1.0, 0.1) var prepare_time: float = 0.5
@export_range(2.0, 10.0, 0.5) var no_gem_timeout: float = 5.0
@export_range(0.5, 5.0, 0.5) var die_duration: float = 5.0
@export_range(5.0, 30.0, 1.0) var max_shake_intensity: float = 12.0
@export_range(200.0, 800.0, 50.0) var extended_search_radius: float = 500.0
@export_range(100.0, 300.0, 25.0) var flee_distance: float = 150.0
@export_range(1000.0, 8000.0, 500.0) var flee_acceleration: float = 3000.0
@export_range(1000.0, 8000.0, 500.0) var flee_deceleration: float = 2000.0
@export var despawn_anim_name: String = "despawn"
@export_range(50.0, 300.0, 25.0) var attract_range: float = 150.0
@export_range(20.0, 150.0, 10.0) var gem_attract_speed: float = 60.0
@export_range(0.1, 2.0, 0.05) var search_interval: float = 0.5

enum State{SEARCHING, MOVING_TO_GEM, PREPARING, SHOOTING, DYING}
var state: int = State.SEARCHING
var target_gem: Area2D = null
var shoot_timer: float = 0.0
var prepare_timer: float = 0.0
var no_gem_timer: float = 0.0
var die_timer: float = 0.0
var flee_direction: Vector2 = Vector2.ZERO
var current_flee_speed: float = 0.0
var max_flee_speed: float = 0.0
var is_attracting: bool = false
var search_timer: float = 0.0

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var e = enemy as EnemyBase
	if not e or not is_instance_valid(player):
		return Vector2.ZERO
	shoot_timer -= delta
	var to_player = player.global_position - e.global_position
	var distance = to_player.length()
	if e.has_method("set_separation"):
		e.set_separation(distance)
	match state:
		State.SEARCHING:
			search_timer -= delta
			if search_timer <= 0.0:
				var gem_count = e.get_tree().get_node_count_in_group("Gem")
				var adjusted_interval = search_interval
				if gem_count > 100:
					adjusted_interval = search_interval * (gem_count / 100.0)
				search_timer = adjusted_interval
				target_gem = _find_nearest_gem(e)
			if target_gem:
				_reserve_gem(target_gem, e)
				state = State.MOVING_TO_GEM
				no_gem_timer = 0.0
				current_flee_speed = 0.0
				_set_attracting(e, false)
				return Vector2.ZERO
			no_gem_timer += delta
			if no_gem_timer >= no_gem_timeout and not e.is_elite:
				state = State.DYING
				die_timer = die_duration
				_start_despawn_sequence(e)
				current_flee_speed = 0.0
				return Vector2.ZERO
			return _flee_from_player(e, player, distance, delta)
		State.MOVING_TO_GEM:
			if not is_instance_valid(target_gem) or _is_gem_invalid(target_gem, e):
				if is_instance_valid(target_gem):
					_unattract_gem(target_gem)
					if "reserved_by" in target_gem:
						target_gem.reserved_by = null
				_set_attracting(e, false)
				target_gem = null
				state = State.SEARCHING
				return Vector2.ZERO
			var dist = e.global_position.distance_to(target_gem.global_position)
			if dist <= attract_range:
				_attract_gem(target_gem, e)
				_set_attracting(e, true)
			else:
				_unattract_gem(target_gem)
				_set_attracting(e, false)
			if dist <= pickup_range:
				state = State.PREPARING
				prepare_timer = prepare_time
				_unattract_gem(target_gem)
				_set_attracting(e, false)
				if target_gem.has_method("prepare_throw"):
					target_gem.prepare_throw()
				return Vector2.ZERO
			var dir = (target_gem.global_position - e.global_position).normalized()
			return dir * e.speed
		State.PREPARING:
			prepare_timer -= delta
			if prepare_timer <= 0.0:
				state = State.SHOOTING
				_shoot_gem(e, player)
			return Vector2.ZERO
		State.SHOOTING:
			if shoot_timer <= 0.0:
				state = State.SEARCHING
			return Vector2.ZERO
		State.DYING:
			die_timer -= delta
			var progress = 1.0 - clampf(die_timer / die_duration, 0.0, 1.0)
			var eased_progress = progress * progress
			if e.visual_node:
				var shake_intensity = eased_progress * max_shake_intensity
				e.visual_node.position = Vector2(randf_range( - shake_intensity, shake_intensity), randf_range( - shake_intensity, shake_intensity))
			if die_timer <= 0.0:
				_release_target_gem()
				_set_attracting(e, false)
				if e.visual_node:
					e.visual_node.position = Vector2.ZERO
				e.die()
			return Vector2.ZERO
	return Vector2.ZERO

func on_death(_enemy: CharacterBody2D) -> void :
	_release_target_gem()
	is_attracting = false

func _release_target_gem() -> void :
	if is_instance_valid(target_gem):
		if target_gem.has_method("stop_attract"):
			target_gem.stop_attract()
		if "reserved_by" in target_gem:
			target_gem.reserved_by = null
		if "is_preparing" in target_gem and target_gem.is_preparing:
			target_gem.is_preparing = false
			if "original_scale" in target_gem:
				target_gem.scale = target_gem.original_scale
	target_gem = null

func _set_attracting(e: EnemyBase, active: bool):
	if active == is_attracting:
		return
	is_attracting = active
	if e.has_method("play_anim"):
		if active:
			e.play_anim("magnet_on")
		else:
			e.play_anim("magnet_off")

func _attract_gem(gem: Area2D, enemy: EnemyBase):
	if is_instance_valid(gem) and gem.has_method("start_attract_to_enemy"):
		gem.start_attract_to_enemy(enemy, gem_attract_speed)

func _unattract_gem(gem: Area2D):
	if is_instance_valid(gem) and gem.has_method("stop_attract"):
		gem.stop_attract()

func _start_despawn_sequence(e: EnemyBase):
	if despawn_anim_name != "" and e.has_method("play_anim"):
		e.play_anim(despawn_anim_name)

func _reserve_gem(gem: Area2D, enemy: EnemyBase):
	if is_instance_valid(gem) and "reserved_by" in gem:
		gem.reserved_by = enemy

func _is_gem_invalid(gem: Area2D, for_enemy: EnemyBase = null) -> bool:
	if not is_instance_valid(gem):
		return true
	if "is_projectile" in gem and gem.is_projectile:
		return true
	if "is_preparing" in gem and gem.is_preparing:
		return true
	if "reserved_by" in gem and gem.reserved_by != null and gem.reserved_by != for_enemy:
		return true
	return false

func _find_nearest_gem(e: EnemyBase) -> Area2D:
	var gems = e.get_tree().get_nodes_in_group("Gem")
	if gems.is_empty():
		return null
	var pos = e.global_position
	var r1 = search_radius * search_radius
	var r2 = extended_search_radius * extended_search_radius
	var nearest1: Area2D = null
	var min_d1 = INF
	var nearest2: Area2D = null
	var min_d2 = INF
	for gem in gems:
		if not is_instance_valid(gem):
			continue
		if _is_gem_invalid(gem, null):
			continue
		var d2 = pos.distance_squared_to(gem.global_position)
		if d2 < min_d1:
			if d2 < r1:
				min_d1 = d2
				nearest1 = gem
			if d2 < min_d2:
				min_d2 = d2
				nearest2 = gem
	return nearest1 if nearest1 != null else nearest2

func _flee_from_player(e: EnemyBase, player: Node2D, distance: float, delta: float) -> Vector2:
	max_flee_speed = e.speed * 0.8
	var target_dir: Vector2
	var target_speed: float
	if distance < flee_distance:
		target_dir = (e.global_position - player.global_position).normalized()
		target_speed = max_flee_speed
	else:
		target_dir = (player.global_position - e.global_position).normalized()
		target_speed = max_flee_speed * 0.4
	if flee_direction == Vector2.ZERO:
		flee_direction = target_dir
	else:
		var blended = flee_direction.lerp(target_dir, 3.0 * delta)
		flee_direction = blended.normalized() if blended.length_squared() > 0.0001 else target_dir
	var accel = flee_acceleration if target_speed > current_flee_speed else flee_deceleration
	current_flee_speed = move_toward(current_flee_speed, target_speed, accel * delta)
	return flee_direction * current_flee_speed

func get_facing(enemy: CharacterBody2D, player: Node2D) -> Vector2:
	match state:
		State.MOVING_TO_GEM:
			if is_instance_valid(target_gem):
				return (target_gem.global_position - enemy.global_position).normalized()
		State.PREPARING, State.SHOOTING:
			if is_instance_valid(player):
				return (player.global_position - enemy.global_position).normalized()
		State.SEARCHING, State.DYING:
			if is_instance_valid(player):
				return (player.global_position - enemy.global_position).normalized()
	return Vector2.ZERO

func _shoot_gem(e: EnemyBase, player: Node2D):
	if not is_instance_valid(target_gem):
		return
	if e.has_method("play_anim"):
		e.play_anim("shoot")
	if target_gem.has_method("throw_at_player"):
		target_gem.throw_at_player(player.global_position, e.damage, xp_multiplier, throw_speed)
	if e.visual_node:
		var tw = e.create_tween()
		tw.tween_property(e.visual_node, "scale", Vector2(0.8, 1.2), 0.1)
		tw.tween_property(e.visual_node, "scale", Vector2.ONE, 0.15)
	if is_instance_valid(target_gem) and "reserved_by" in target_gem:
		target_gem.reserved_by = null
	target_gem = null
	shoot_timer = shoot_cooldown
