class_name EnemyBase
extends CharacterBody2D

var is_segment: bool = false
var ignore_knockback: bool = false
var necro_group_leader: EnemyBase = null
var summoner: EnemyBase = null
var type: Enemy
var no_smoothing: bool = false
var scale_mult: float = 1.0
var lock_rotation: bool = false
var no_squash: bool = false
var no_collision_move: bool = false
@export var player_ref: Node2D
@export var is_elite: bool = false:
	set(value):
		if is_elite == value:
			return
		is_elite = value
		_apply_elite_stats()
		_apply_elite_visuals()
@export_range(1.0, 10.0, 0.5) var elite_health_mult: float = 2.0
@export_range(1.0, 10.0, 0.5) var elite_damage_mult: float = 1.5
var health: float
var ai: EnemyAIBehavior
var damage: float = 0.0
var speed: float = 125.0
var knockback: Vector2 = Vector2.ZERO
var separation: float = 0.0
var is_dying: bool = false
var current_move_velocity: Vector2 = Vector2.ZERO
var move_acceleration: float = 5000.0
var visual_node: Node2D
var particles: CPUParticles2D
var dash_particles: CPUParticles2D
var speed_up_particles: CPUParticles2D
var run_particles_enabled: bool = true
var is_necromancer: bool = false
var orbit_offset: float = 0.0
var force_particles: bool = false
var collision_shape: CollisionShape2D
signal enemy_died(enemy: EnemyBase)
signal enemy_damaged(enemy: EnemyBase, amount: float, is_crit: bool)
var _elite_stats_applied: bool = false
var _stats_initialized: bool = false
var _flash_timer: float = 0.0
var net_id: int = 0
static var _next_net_id: int = 1
var _dummy_attack_cd: Dictionary = {}
@export var dummy_attack_range: float = 60.0
@export var dummy_attack_cooldown: float = 1.0
var _target_update_acc: float = 0.0
const TARGET_UPDATE_INTERVAL: float = 0.3

func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not Net.is_host:
		queue_free()
		return
	if not type:
		queue_free()
		return
	if is_segment:
		no_collision_move = true
	damage = type.damage
	health = type.health
	speed = type.speed
	_stats_initialized = true
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("Player")
	_setup_collision()
	if multiplayer.has_multiplayer_peer() and Net.is_host:
		net_id = _next_net_id
		_next_net_id += 1
	_setup_visual()
	_apply_elite_stats()
	_apply_elite_visuals()
	if type.ai_behavior:
		ai = type.ai_behavior.duplicate()
		if ai.has_method("on_spawn"):
			ai.on_spawn(self, _get_valid_target())
	_play_spawn_effect()

func _get_valid_target() -> Node2D:
	if player_ref and is_instance_valid(player_ref):
		return player_ref
	_update_target()
	if player_ref and is_instance_valid(player_ref):
		return player_ref
	return null

func _drop_item() -> void:
	if type.drops.is_empty():
		return
	var drop_data: Pickups
	if is_elite and type.elite_guaranteed_drop:
		drop_data = type.elite_guaranteed_drop
	else:
		drop_data = Enemy.pick_weighted(type.drops)
	if not drop_data:
		return
	var pickup_scene = preload("res://scene/pickup.tscn")
	var pickup = pickup_scene.instantiate()
	pickup.type = drop_data
	pickup.global_position = global_position
	pickup.player_ref = get_tree().get_first_node_in_group("Player")
	get_tree().current_scene.add_child.call_deferred(pickup)

func _update_target() -> void:
	var candidates: Array = []
	var local_p = get_tree().get_first_node_in_group("Player")
	if local_p and is_instance_valid(local_p) and not local_p.is_dead:
		candidates.append(local_p)
	for d in get_tree().get_nodes_in_group("RemotePlayer"):
		if not is_instance_valid(d):
			continue
		if d.modulate.a <= 0.5:
			continue
		if "_is_dead_dummy" in d and d._is_dead_dummy:
			continue
		candidates.append(d)
	if candidates.is_empty():
		player_ref = null
		return
	var nearest = candidates[0]
	var min_d = global_position.distance_squared_to(nearest.global_position)
	for i in range(1, candidates.size()):
		var d2 = global_position.distance_squared_to(candidates[i].global_position)
		if d2 < min_d:
			min_d = d2
			nearest = candidates[i]
	player_ref = nearest

func _apply_elite_stats() -> void:
	if is_elite and _stats_initialized and not _elite_stats_applied:
		health *= elite_health_mult
		damage *= elite_damage_mult
		_elite_stats_applied = true

func _setup_collision() -> void:
	collision_shape = $CollisionShape2D
	add_to_group("Enemy")

func on_touch_player(player: CharacterBody2D) -> void:
	if ai and ai.has_method("on_touch_player"):
		ai.on_touch_player(self, player)

func explode_fx(tex_override: Texture2D = null) -> void:
	var tex: Texture2D = tex_override
	if not tex:
		if visual_node is Sprite2D:
			tex = visual_node.texture
		elif visual_node is AnimatedSprite2D and visual_node.sprite_frames:
			tex = visual_node.sprite_frames.get_frame_texture(visual_node.animation, visual_node.frame)
	if not tex:
		return
	var flash = Sprite2D.new()
	flash.texture = tex
	flash.modulate = Color(2.0, 1.6, 1.0, 0.9)
	flash.global_position = global_position
	flash.scale = scale
	get_tree().current_scene.add_child(flash)
	var tw = flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", scale * 3.0, 0.25)
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.set_parallel(false)
	tw.tween_callback(flash.queue_free)
	for i in range(4):
		var shard = Sprite2D.new()
		shard.texture = tex
		shard.modulate = Color(1.6, 1.0, 0.5, 0.9)
		shard.global_position = global_position
		shard.scale = scale * 0.4
		get_tree().current_scene.add_child(shard)
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		var st = shard.create_tween().set_parallel(true)
		st.tween_property(shard, "global_position", shard.global_position + dir * randf_range(40.0, 90.0), 0.3)
		st.tween_property(shard, "modulate:a", 0.0, 0.3)
		st.tween_property(shard, "rotation", randf_range(-4.0, 4.0), 0.3)
		st.set_parallel(false)
		st.tween_callback(shard.queue_free)

func screen_shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var tw = camera.create_tween()
	var steps = int(duration / 0.05)
	for i in range(steps):
		var decay = 1.0 - float(i) / steps
		tw.tween_property(
			camera, "offset",
			Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * decay,
			0.05
		)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func _apply_elite_visuals() -> void:
	if not is_elite:
		return
	scale = Vector2(2, 2)
	if visual_node:
		visual_node.material = ShaderPool.outline

func _setup_visual() -> void:
	visual_node = get_node_or_null("AnimatedSprite2D")
	if not visual_node:
		visual_node = get_node_or_null("Sprite2D")
	if not visual_node:
		var sprite = Sprite2D.new()
		add_child(sprite)
		visual_node = sprite
	if visual_node is Sprite2D and type.texture:
		visual_node.texture = type.texture
	particles = get_node_or_null("CPUParticles2D")
	dash_particles = get_node_or_null("DashParticles")
	speed_up_particles = get_node_or_null("SpeedUpParticles")

func play_anim(anim: String) -> void:
	var a = visual_node as AnimatedSprite2D
	if a and a.sprite_frames and a.sprite_frames.has_animation(anim):
		if a.animation != anim:
			a.play(anim)

var invincible: bool = false
func set_invincible(duration: float) -> void:
	invincible = true
	var blink = create_tween().set_loops(ceili(duration / 0.2))
	blink.tween_property(self, "modulate:a", 0.35, 0.1)
	blink.tween_property(self, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(duration).timeout
	blink.kill()
	modulate.a = 1.0
	invincible = false

func _physics_process(delta: float) -> void:
	if is_dying or not type:
		return
	if multiplayer.has_multiplayer_peer() and Net.is_host:
		_target_update_acc += delta
		if _target_update_acc >= TARGET_UPDATE_INTERVAL:
			_target_update_acc = 0.0
			_update_target()
	if not _ensure_target():
		return
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and visual_node:
			visual_node.modulate = Color.WHITE
	var desired_velocity := Vector2.ZERO
	if ai:
		desired_velocity = ai.calculate_movement(self, player_ref, delta)
	if ignore_knockback:
		knockback = Vector2.ZERO
	else:
		knockback = knockback.move_toward(Vector2.ZERO, 400.0 * delta)
	var final_velocity = desired_velocity + knockback
	if no_smoothing:
		current_move_velocity = final_velocity
	else:
		current_move_velocity = current_move_velocity.move_toward(final_velocity, move_acceleration * delta)
	if no_collision_move:
		global_position += current_move_velocity * delta
	else:
		var collider = move_and_collide(current_move_velocity * delta)
		_handle_collision(collider)
	var facing := current_move_velocity.normalized()
	if ai and ai.has_method("get_facing"):
		var f: Vector2 = ai.get_facing(self, player_ref)
		if f != Vector2.ZERO:
			facing = f
	_update_visual_effects(delta, facing)
	_check_attack_dummies(delta)

func _ensure_target() -> bool:
	if not player_ref or not is_instance_valid(player_ref):
		_update_target()
		if not player_ref or not is_instance_valid(player_ref):
			return false
	return true

func _check_attack_dummies(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not Net.is_host:
		return
	for d in get_tree().get_nodes_in_group("RemotePlayer"):
		if not is_instance_valid(d):
			continue
		if "_is_dead_dummy" in d and d._is_dead_dummy:
			continue
		var pid = d.peer_id
		var cd = _dummy_attack_cd.get(pid, 0.0)
		if cd > 0.0:
			_dummy_attack_cd[pid] = cd - delta
			continue
		var dist = global_position.distance_to(d.global_position)
		if dist > dummy_attack_range:
			continue
		_dummy_attack_cd[pid] = dummy_attack_cooldown
		Net.send_player_damage(pid, damage)

func _handle_collision(collider: KinematicCollision2D) -> void:
	if not collider:
		return
	var target = collider.get_collider()
	if not target or not is_instance_valid(target):
		return
	var dir = -collider.get_normal()
	if dir == Vector2.ZERO:
		dir = (target.global_position - global_position).normalized()
	if target.has_method("apply_knockback"):
		target.apply_knockback(dir * 10.0)

func _update_visual_effects(delta: float, direction: Vector2) -> void:
	if not visual_node:
		return
	if direction != Vector2.ZERO and not lock_rotation:
		var target_angle = direction.angle()
		rotation = lerp_angle(rotation, target_angle, 20.0 * delta)
	var target_scale := Vector2(1.0, 1.0)
	if direction != Vector2.ZERO and not no_squash:
		target_scale = Vector2(1.1, 0.9)
	target_scale *= scale_mult
	if no_smoothing:
		visual_node.scale = target_scale
	else:
		visual_node.scale = visual_node.scale.lerp(target_scale, 15.0 * delta)
	if particles:
		particles.emitting = run_particles_enabled and (force_particles or (direction != Vector2.ZERO and separation < 700.0))

func set_separation(value: float) -> void:
	separation = value
	if player_ref and is_instance_valid(player_ref) and "nearest_enemy_distance" in player_ref and separation < player_ref.nearest_enemy_distance:
		player_ref.nearest_enemy = self

func apply_knockback(amount: Vector2) -> void:
	knockback += amount

func apply_endgame_buff(hp_bonus: float, dmg_bonus: float) -> void:
	health += hp_bonus
	damage += dmg_bonus

func take_damage(amount: float) -> void:
	if is_dying or invincible:
		return
	var luck: float = 1.0
	if player_ref and is_instance_valid(player_ref) and "luck" in player_ref:
		luck = player_ref.luck
	var crit_chance = 1.0 - (1.0 / max(luck, 1.0))
	var is_crit = randf() < crit_chance
	var modifier = 2.0 if is_crit else 1.0
	var final_damage = amount * modifier
	health -= final_damage
	enemy_damaged.emit(self, final_damage, is_crit)
	_spawn_damage_popup(final_damage, is_crit)
	_flash_damage()
	if health <= 0.0:
		die()

func die() -> void:
	if is_dying:
		return
	is_dying = true
	set_physics_process(false)
	remove_from_group("Enemy")
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if player_ref and is_instance_valid(player_ref) and "nearest_enemy" in player_ref and player_ref.nearest_enemy == self:
		player_ref.nearest_enemy = null
		if "area" in player_ref:
			player_ref.nearest_enemy_distance = 250.0 + player_ref.area
	if ai and ai.has_method("on_death"):
		ai.on_death(self)
	enemy_died.emit(self)
	if particles:
		particles.emitting = false
	if get_node_or_null("SpeedUpParticles"):
		$SpeedUpParticles.emitting = false
	_drop_item()
	if is_segment:
		queue_free()
		return
	await _play_death_effect()
	queue_free()

func is_dying_now():
	if is_dying:
		print("DIED")
	return is_dying

func _spawn_damage_popup(amount: float, is_crit: bool) -> void:
	DamagePopup.spawn(global_position, amount, is_crit)

func _flash_damage() -> void:
	if not visual_node or not ("modulate" in visual_node):
		return
	visual_node.modulate = Color(0.2, 0.2, 0.2)
	_flash_timer = 0.08

func _play_spawn_effect() -> void:
	if is_segment:
		return
	if visual_node and visual_node is Sprite2D:
		var burn_mat = ShaderPool.burn.duplicate() as ShaderMaterial
		burn_mat.set_shader_parameter("position", Vector2(randf(), randf()))
		burn_mat.set_shader_parameter("radius", 2.0)
		visual_node.material = burn_mat
		var tween = create_tween()
		tween.tween_method(_set_burn_radius, 2.0, 0.0, 1.0)
		tween.finished.connect(func():
			if is_elite:
				visual_node.material = ShaderPool.outline
			else:
				visual_node.material = null
		)
	else:
		if visual_node:
			visual_node.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(visual_node, "modulate:a", 1.0, 0.8)

func _play_death_effect() -> void:
	if not visual_node:
		return
	var burn_mat = ShaderPool.burn.duplicate() as ShaderMaterial
	burn_mat.set_shader_parameter("position", Vector2(randf(), randf()))
	visual_node.material = burn_mat
	var tween = create_tween()
	tween.tween_method(_set_burn_radius, 0.0, 2.0, 1.0)
	await tween.finished

func _set_burn_radius(value: float) -> void:
	if visual_node and visual_node.material:
		visual_node.material.set_shader_parameter("radius", value)

func teleport_to(pos: Vector2) -> void:
	_teleport_flash(global_position)
	global_position = pos
	knockback = Vector2.ZERO
	_teleport_flash(pos)
	if ai and ai.has_method("on_teleported"):
		ai.on_teleported(self)

func _teleport_flash(pos: Vector2) -> void:
	var tex: Texture2D = null
	if visual_node is Sprite2D:
		tex = visual_node.texture
	elif visual_node is AnimatedSprite2D and visual_node.sprite_frames:
		tex = visual_node.sprite_frames.get_frame_texture(visual_node.animation, visual_node.frame)
	var f = Sprite2D.new()
	f.texture = tex
	f.modulate = Color(1.5, 1.5, 2.0, 0.8)
	f.global_position = pos
	f.rotation = rotation
	f.scale = scale * (visual_node.scale if visual_node else Vector2.ONE)
	if visual_node is AnimatedSprite2D:
		f.flip_h = visual_node.flip_h
	get_tree().current_scene.add_child(f)
	var tw = f.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", f.scale * 2.0, 0.2)
	tw.tween_property(f, "modulate:a", 0.0, 0.2)
	tw.set_parallel(false)
	tw.tween_callback(f.queue_free)
