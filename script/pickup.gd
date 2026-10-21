extends Area2D

var direction: Vector2
var speed: float = 210
var add_speed: float = 1
var reserved_by: Node2D = null
@export var type: Pickups
@export var max_xp_on_field: int = 100
@export var player_ref: CharacterBody2D:
	set(value):
		player_ref = value
		if type:
			type.player_ref = value
var can_follow: bool = false
var _collected: bool = false
var _base_modulate: Color = Color.WHITE
var bonus_xp: float = 0
var is_projectile: bool = false
var projectile_damage: float = 10.0
var xp_multiplier: float = 1.0
var projectile_speed: float = 400.0
var projectile_direction: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0
var max_distance: float = 1500.0
var explosion_radius: float = 70.0
var explosion_damage_mult: float = 0.5
var explosion_knockback: float = 120.0
var is_preparing: bool = false
var prepare_timer: float = 0.0
var original_scale: Vector2 = Vector2.ONE
var is_mega: bool = false
var mega_drift_speed: float = 30.0
var mega_drift_distance: float = 400.0
var attracted_by_enemy: Node2D = null
var attract_speed: float = 60.0
var net_id: int = 0
static var _next_pickup_id: int = 1

func _ready() -> void :
	if multiplayer.has_multiplayer_peer() and Net.is_host:
		net_id = _next_pickup_id
		_next_pickup_id += 1
	if multiplayer.has_multiplayer_peer():
		add_to_group("PickupNet")
	_base_modulate = modulate
	original_scale = scale
	if type:
		$Sprite2D.texture = type.icon
	if type is Gem:
		add_to_group("Gem")
		if max_xp_on_field > 0:
			await get_tree().process_frame
			if not is_instance_valid(self): return
			var all_gems = get_tree().get_nodes_in_group("Gem")
			if all_gems.size() > max_xp_on_field:
				var mega_gems = get_tree().get_nodes_in_group("MegaGem")
				if mega_gems.size() > 0:
					mega_gems[0].add_bonus_xp(type.XP)
					remove_from_group("Gem")
					queue_free()
					return
				else:
					var others = all_gems.filter( func(g): return g != self)
					if others.size() > 0:
						var target = others[0]
						target.make_mega_gem()
						target.add_bonus_xp(type.XP)
						remove_from_group("Gem")
						queue_free()
						return
	else:
		add_to_group("PickupItem")

func make_mega_gem():
	is_mega = true
	add_to_group("MegaGem")
	_base_modulate = Color.YELLOW
	modulate = Color.YELLOW
	scale = Vector2(2.0, 2.0)
	original_scale = scale
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(2.2, 2.2), 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.5).set_ease(Tween.EASE_IN_OUT)

func add_bonus_xp(amount: float):
	bonus_xp += amount
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.1)
	tween.tween_property(self, "scale", original_scale, 0.2)

func start_attract_to_enemy(enemy: Node2D, spd: float = 60.0):
	attracted_by_enemy = enemy
	attract_speed = spd

func stop_attract():
	attracted_by_enemy = null

func prepare_throw():
	is_preparing = true
	prepare_timer = 0.5
	attracted_by_enemy = null

func throw_at_player(target_pos: Vector2, damage: float, xp_mult: float, throw_spd: float = 400.0):
	is_projectile = true
	is_preparing = false
	projectile_damage = damage
	xp_multiplier = xp_mult
	projectile_speed = throw_spd
	projectile_direction = (target_pos - global_position).normalized()
	distance_traveled = 0.0
	can_follow = false
	reserved_by = null
	attracted_by_enemy = null
	if has_node("Sprite2D"):
		$Sprite2D.rotation = projectile_direction.angle() + PI / 2

func _physics_process(delta: float) -> void :
	if _collected:
		return
	_check_enemy_validity()
	if is_preparing:
		prepare_timer -= delta
		var shake_intensity = (0.5 - prepare_timer) / 0.5 * 0.1
		scale = original_scale + Vector2(randf_range( - shake_intensity, shake_intensity), randf_range( - shake_intensity, shake_intensity))
		if prepare_timer <= 0.0:
			scale = original_scale
		return
	if is_projectile:
		var move_vec = projectile_direction * projectile_speed * delta
		global_position += move_vec
		distance_traveled += move_vec.length()
		if has_node("Sprite2D"):
			var target_rotation = projectile_direction.angle() + PI / 2
			$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, target_rotation, 15.0 * delta)
		if distance_traveled > max_distance:
			_explode_gem(false)
		return
	if is_mega and player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist > mega_drift_distance:
			var drift_dir = (player_ref.global_position - global_position).normalized()
			global_position += drift_dir * mega_drift_speed * delta
	_handle_attraction_and_follow(delta)

func _check_enemy_validity() -> void :
	if reserved_by and not is_instance_valid(reserved_by):
		reserved_by = null
		can_follow = true
	if attracted_by_enemy and not is_instance_valid(attracted_by_enemy):
		attracted_by_enemy = null
		can_follow = true

func _handle_attraction_and_follow(delta: float) -> void :
	var moving_to_player = false
	var moving_to_enemy = false
	if player_ref and can_follow and is_instance_valid(player_ref):
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		var enemy_closer = false
		if is_instance_valid(attracted_by_enemy):
			var dist_to_enemy = global_position.distance_to(attracted_by_enemy.global_position)
			if dist_to_enemy < dist_to_player:
				enemy_closer = true
		if enemy_closer:
			var dir_to_enemy = (attracted_by_enemy.global_position - global_position).normalized()
			global_position += dir_to_enemy * attract_speed * delta
			if has_node("Sprite2D"):
				$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, dir_to_enemy.angle() + PI / 2, 10.0 * delta)
			moving_to_enemy = true
		else:
			direction = (player_ref.position - position).normalized()
			position += direction * delta * speed * add_speed
			if has_node("Sprite2D"):
				$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, direction.angle() + PI / 2, 20.0 * delta)
			add_speed += 0.01
			moving_to_player = true
	elif is_instance_valid(attracted_by_enemy):
		var dir_to_enemy = (attracted_by_enemy.global_position - global_position).normalized()
		global_position += dir_to_enemy * attract_speed * delta
		if has_node("Sprite2D"):
			$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, dir_to_enemy.angle() + PI / 2, 10.0 * delta)
		moving_to_enemy = true
	if not moving_to_player and not moving_to_enemy and can_follow and player_ref:
		direction = (player_ref.position - position).normalized()
		position += direction * delta * speed * add_speed
		if has_node("Sprite2D"):
			$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, direction.angle() + PI / 2, 20.0 * delta)
		add_speed += 0.01

func follow(_target: CharacterBody2D, gem_flag: bool = false) -> void :
	if type is CardResource:
		return
	if gem_flag == true:
		if type is Gem:
			can_follow = true
		return
	can_follow = true

func _on_body_entered(_body: Node2D) -> void :
	if _collected:
		return
	if is_projectile:
		if _body == player_ref:
			_explode_gem(true)
		return
	_collected = true
	if multiplayer.has_multiplayer_peer():
		if Net.is_host:
			_apply_collection(multiplayer.get_unique_id())
		else:
			if net_id > 0:
				Net.send_pickup_collected(net_id)
			queue_free()
		return
	if type:
		type.activate()
		var base_xp = type.XP if "XP" in type else 0.0
		var final_xp = (base_xp + bonus_xp) * xp_multiplier
		if player_ref:
			player_ref.gain_XP(final_xp)
	queue_free()

func _apply_collection(collector_id: int) -> void :
	var base_xp = type.XP if (type and "XP" in type) else 0.0
	var final_xp = (base_xp + bonus_xp) * xp_multiplier
	if type:
		type.activate()
	if collector_id == multiplayer.get_unique_id():
		if player_ref:
			player_ref.gain_XP(final_xp)
	else:
		Net.send_xp(collector_id, final_xp)
	queue_free()



func _explode_gem(direct_hit_player: bool) -> void :
	if _collected:
		return
	_collected = true
	reserved_by = null
	attracted_by_enemy = null
	var tex: Texture2D = null
	if has_node("Sprite2D"):
		tex = $Sprite2D.texture
	if tex:
		var flash = Sprite2D.new()
		flash.texture = tex
		flash.modulate = Color(2.5, 2.0, 1.5, 0.9)
		flash.global_position = global_position
		flash.scale = scale
		get_tree().current_scene.add_child(flash)
		var tw = flash.create_tween().set_parallel(true)
		tw.tween_property(flash, "scale", scale * 4.0, 0.2)
		tw.tween_property(flash, "modulate:a", 0.0, 0.2)
		tw.set_parallel(false)
		tw.tween_callback(flash.queue_free)
		for i in range(3):
			var shard = Sprite2D.new()
			shard.texture = tex
			shard.modulate = Color(1.8, 1.2, 0.6, 0.9)
			shard.global_position = global_position
			shard.scale = scale * 0.5
			get_tree().current_scene.add_child(shard)
			var dir = Vector2.RIGHT.rotated(randf() * TAU)
			var st = shard.create_tween().set_parallel(true)
			st.tween_property(shard, "global_position", shard.global_position + dir * randf_range(50.0, 120.0), 0.4)
			st.tween_property(shard, "modulate:a", 0.0, 0.4)
			st.tween_property(shard, "rotation", randf_range(-6.0, 6.0), 0.4)
			st.set_parallel(false)
			st.tween_callback(shard.queue_free)
	if player_ref and is_instance_valid(player_ref):
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		var aoe_damage = projectile_damage * explosion_damage_mult
		var hit_player = false
		if direct_hit_player:
			hit_player = true
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(projectile_damage)
			var knockback_dir = (player_ref.global_position - global_position).normalized()
			if knockback_dir == Vector2.ZERO:
				knockback_dir = - projectile_direction
			if player_ref.has_method("apply_knockback"):
				player_ref.apply_knockback(knockback_dir * explosion_knockback)
		elif dist_to_player <= explosion_radius:
			hit_player = true
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(aoe_damage)
			var knockback_dir = (player_ref.global_position - global_position).normalized()
			if knockback_dir == Vector2.ZERO:
				knockback_dir = - projectile_direction
			if player_ref.has_method("apply_knockback"):
				var falloff = 1.0 - (dist_to_player / explosion_radius)
				player_ref.apply_knockback(knockback_dir * explosion_knockback * falloff)
		if hit_player and type:
			type.activate()
			var base_xp = type.XP if "XP" in type else 0.0
			var final_xp = (base_xp + bonus_xp) * xp_multiplier
			player_ref.gain_XP(final_xp)
	queue_free()
