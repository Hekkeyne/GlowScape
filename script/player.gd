extends CharacterBody2D

var nearest_enemy 
var nearest_enemy_distance: float = 0+area
var movement_speed : float = 0
var recovery:float=0 
var armor:float = 0
var might : float =0
var area: float = 0
var growth:float=0
var can_dash : bool=true
var is_invincible: bool = false
var is_dead: bool = false
@export var invincible_duration: float = 1.0
@export var character : Character
var current_velocity: Vector2 = Vector2.ZERO
@export var acceleration: float = 800.0
@export var deceleration: float = 1200.0
@export var sfx_tp : AudioStream=load("res://resourse/audio/tp_sfx_1.wav")
@export var death_wait_time: float = 1.0
@export var death_fade_time: float = 0.8
@export var button_slide_time: float = 0.5
@export var enemy_wave_speed: float = 800.0
@export var enemy_fade_time: float = 0.4
var microchips: int = 0:
	set(value):
		microchips=value
		%Microchips.text = tr("TR_CHIPS") % str(value)
var magnet:float=0:
	set(value):
		magnet=value
		$Magnet/Magnet.shape.radius=100+value
var max_health : float=0:
	set(value):
		max_health=value
		%health.max_value=value
var XP : float = 0:
	set(value):
		XP=value
		%XP.value=value
var total_XP : float = 0
var level : int=1:
	set(value):
		level=value
		%Level.text=tr("LABEL_LEVEL") % str(value) 
		%Options.queue_level_up()
		%XP.max_value = BASE_XP + (value * 0.25 * BASE_XP)
		if value>=30:
			%XP.max_value = BASE_XP + (value * 0.5 * BASE_XP)
var BASE_XP = 100
var health : float = max_health:
	set(value):
		health = clampf(value, 0.0, max_health)
		%health.value=value
		%HealthLabel.text = tr("LABEL_HEALTH") % str(int(health))
		if health <= 0.0 and not is_dead:
			_die()
var luck : float = 1.0
@onready var sprite: Sprite2D = $Sprite2D
@onready var particles : CPUParticles2D = $player
@onready var target_point = $TargetPoint
@onready var back_button: TextureButton = $UI/Back
var back_button_final_pos: Vector2 = Vector2.ZERO
@export var teleport_distance: float = 200.0 
@export var point_lerp_speed: float = 10.0
var _snap_acc: float = 0.0
var _net_ready: bool = false

func _ready() -> void:
	character = Persistence.character
	Persistence.gain_bonus_stats(self)
	add_to_group("Player")
	$Sprite2D.texture=character.texture
	%Level.text=tr("LABEL_LEVEL") % str(level) 
	%Microchips.text = tr("TR_CHIPS") % str(microchips)
	%HealthLabel.text = tr("LABEL_HEALTH") % str(int(health))
	set_base_stats(character.base_stats)
	%Options.check_item(character.starting_weapon)
	$player.modulate=Color.from_string(character.color_trail,Color.WHITE)
	if back_button:
		back_button_final_pos = back_button.position
		back_button.position.y = -150
		back_button.visible = false
	%XP.max_value=BASE_XP
	Net.set_character(character)
	await get_tree().process_frame
	_net_ready = true

func _can_rpc() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	if not Net.session_active:
		return false
	if not is_inside_tree():
		return false
	if not _net_ready:
		return false
	return true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_instance_valid(nearest_enemy):
		nearest_enemy_distance = global_position.distance_to(nearest_enemy.global_position)
	else:
		nearest_enemy_distance = 250+area
		nearest_enemy=null
	var direction = Input.get_vector("left", "right", "up","down")
	if (Input.is_action_just_pressed("dash")) and can_dash:
		%Teleport.value = 0
		$start_teleport.emitting = true
		$SFX.stream = sfx_tp
		$SFX.pitch_scale = randf_range(0.7, 1.3)
		$SFX.volume_db = -15
		$SFX.play()
		teleport_flash(global_position)
		global_position += direction * teleport_distance
		%TargetPoint.modulate = Color.WHITE
		can_dash = false
		%dash_cooldown.start()
		create_tween().tween_property(%Teleport, "value", 100, 1)
		if _can_rpc():
			_send_dash.rpc(global_position)
	knockback = knockback.move_toward(Vector2.ZERO, 400.0 * delta)
	var target_velocity = direction * movement_speed
	if direction != Vector2.ZERO:
		current_velocity = current_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration * delta)
	velocity = current_velocity + knockback
	move_and_collide(velocity * delta)
	animate_squash(direction, delta)
	rotate_sprite(direction, delta)
	check_XP()
	health+=recovery*delta
	var target_pos = Vector2.ZERO
	if direction != Vector2.ZERO:
		target_pos = direction * teleport_distance
		target_point.rotation = direction.angle()
	else:
		target_pos = Vector2.ZERO
	target_point.position = target_point.position.lerp(target_pos, point_lerp_speed * delta)
	if _can_rpc():
		_snap_acc += delta
		if _snap_acc >= 0.033:
			_snap_acc = 0.0
			var ht = clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 1.0
			_send_snap.rpc(global_position, current_velocity, ht, sprite.rotation)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _send_snap(pos: Vector2, vel: Vector2, health_t: float, rot: float) -> void:
	var id = multiplayer.get_remote_sender_id()
	var node = get_tree().get_first_node_in_group("RemotePlayers_%d" % id)
	if node and is_instance_valid(node) and node.has_method("network_snap"):
		node.network_snap(pos, vel, health_t, rot)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _send_dash(dest: Vector2) -> void:
	var id = multiplayer.get_remote_sender_id()
	var node = get_tree().get_first_node_in_group("RemotePlayers_%d" % id)
	if node and is_instance_valid(node) and node.has_method("network_dash"):
		node.network_dash(dest)

@rpc("any_peer", "reliable", "call_remote")
func _send_dead() -> void:
	var id = multiplayer.get_remote_sender_id()
	var node = get_tree().get_first_node_in_group("RemotePlayers_%d" % id)
	if node and is_instance_valid(node) and node.has_method("network_dead"):
		node.network_dead()

func teleport_flash(pos: Vector2) -> void:
	var f = Sprite2D.new()
	f.texture = sprite.texture
	f.modulate = Color(1.5, 1.5, 2.0, 0.8)
	f.global_position = pos
	f.rotation = sprite.rotation
	f.scale = sprite.scale
	f.flip_h = sprite.flip_h
	f.flip_v = sprite.flip_v
	get_tree().current_scene.add_child(f)
	var tw = f.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", sprite.scale * 2.0, 0.2)
	tw.tween_property(f, "modulate:a", 0.0, 0.2)
	tw.set_parallel(false)
	tw.tween_callback(f.queue_free)

func animate_squash(direction: Vector2, delta: float) -> void:
	var target_scale = Vector2(1.0, 1.0)
	if direction != Vector2.ZERO:
		target_scale = Vector2(1.1, 0.9)
		particles.emitting=true
	else:
		target_scale = Vector2(1.0, 1.0)
		particles.emitting=false
	sprite.scale = sprite.scale.lerp(target_scale, 15.0 * delta)

func rotate_sprite(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		var target_angle = direction.angle()
		sprite.rotation = lerp_angle(sprite.rotation, target_angle, 20.0 * delta)
		particles.rotation = lerp_angle(sprite.rotation, target_angle, 20.0 * delta)

var knockback: Vector2 = Vector2.ZERO

func apply_knockback(amount: Vector2) -> void:
	knockback += amount

func take_damage(amount):
	if is_dead or is_invincible:
		return
	health -= max(amount / ((armor + 100) / 100), 0)
	_start_invincibility()

func _start_invincibility() -> void:
	is_invincible = true
	_flash_invincibility()
	await get_tree().create_timer(invincible_duration).timeout
	if not is_dead:
		is_invincible = false
		sprite.modulate.a = 1.0

func _flash_invincibility() -> void:
	var dim_time = maxf(invincible_duration - 0.5, 0.0)
	var flash_duration = 0.5
	var flash_count = 5
	var flash_step = flash_duration / float(flash_count)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.0)
	if dim_time > 0.0:
		tw.tween_interval(dim_time)
	for i in range(flash_count):
		var target_alpha = 1.0 if i % 2 == 0 else 0.0
		tw.tween_property(sprite, "modulate:a", target_alpha, flash_step)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	$CollisionShape2D.set_deferred("disabled", true)
	is_invincible = false
	can_dash = false
	$UI/XP.visible = false
	%health.visible = false
	%Panel.visible = false
	$UI/weapons.visible = false
	$UI/PassiveItems.visible = false
	%Teleport.visible = false
	$UI/Card.visible = false
	$UI/Pause_Mode.visible = true
	_disable_weapons()
	if particles:
		particles.emitting = false
	_set_game_pause(true)
	if _can_rpc():
		_send_dead.rpc()
		Net.request_revive_zone(global_position, multiplayer.get_unique_id())
		_disable_combat()
		_enable_spectator()
		_check_show_exit_deferred()
	else:
		_wave_clear_enemies()
		_show_exit_button()
	var rotation_dir = 1.0 if randf() < 0.5 else -1.0
	var rotation_amount = randf_range(2.0, 5.0) * TAU * rotation_dir
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(death_wait_time)
	tw.tween_property(sprite, "modulate:a", 0.0, death_fade_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "scale", Vector2.ZERO, death_fade_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "rotation", sprite.rotation + rotation_amount, death_fade_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _disable_weapons() -> void:
	for slot in $UI/weapons.get_children():
		if slot.has_method("set_enabled"):
			slot.set_enabled(false)
		slot.set_process(false)
		slot.set_physics_process(false)

func _enable_weapons() -> void:
	for slot in $UI/weapons.get_children():
		if slot.has_method("set_enabled"):
			slot.set_enabled(true)
		slot.set_process(true)
		slot.set_physics_process(true)

func revive() -> void:
	if not is_dead:
		return
	is_dead = false
	is_invincible = true
	can_dash = true
	health = max_health * 0.5
	$CollisionShape2D.set_deferred("disabled", false)
	$UI/XP.visible = true
	%health.visible = true
	%Panel.visible = true
	$UI/weapons.visible = true
	$UI/PassiveItems.visible = true
	%Teleport.visible = true
	_enable_combat()
	_enable_weapons()
	if $Magnet:
		$Magnet.set_deferred("monitoring", true)
		$Magnet.set_deferred("monitorable", true)
	sprite.modulate.a = 1.0
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	_set_game_pause(false)
	var sm = get_tree().get_first_node_in_group("SpectatorManager")
	if sm != null and sm.has_method("stop_spectating"):
		sm.stop_spectating()
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.global_position = global_position
	await get_tree().create_timer(2.0).timeout
	is_invincible = false

func _check_show_exit_deferred() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	if _all_players_dead():
		_show_exit_button()
	if Net.is_host:
		_check_all_players_dead_host()

func _check_all_players_dead_host() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	if not Net.is_host:
		return
	if _all_players_dead_host():
		Net.broadcast_all_players_dead()

func _all_players_dead_host() -> bool:
	var local_p = get_tree().get_first_node_in_group("Player")
	if local_p and is_instance_valid(local_p) and not local_p.is_dead:
		return false
	for d in get_tree().get_nodes_in_group("RemotePlayer"):
		if not is_instance_valid(d):
			continue
		if "_is_dead_dummy" in d and not d._is_dead_dummy:
			return false
	return true

func _disable_combat() -> void:
	if $Magnet:
		$Magnet.set_deferred("monitoring", false)
		$Magnet.set_deferred("monitorable", false)
	set_physics_process(false)
	if $UI:
		_stop_node_tree($UI/weapons)
		_stop_node_tree($UI/PassiveItems)
func _enable_combat() -> void:
	if $Magnet:
		$Magnet.set_deferred("monitoring", true)
		$Magnet.set_deferred("monitorable", true)
	set_physics_process(true)
	if $UI:
		_start_node_tree($UI/weapons)
		_start_node_tree($UI/PassiveItems)

func _start_node_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.set_process(true)
	node.set_physics_process(true)
	if node is Timer:
		node.paused = false
	for c in node.get_children():
		_start_node_tree(c)

func _stop_node_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.set_process(false)
	node.set_physics_process(false)
	if node is Timer:
		node.paused = true
	for c in node.get_children():
		_stop_node_tree(c)

func _all_players_dead() -> bool:
	if not is_dead:
		return false
	for id in Net.peer_names:
		if id == multiplayer.get_unique_id():
			continue
		var node = get_tree().get_first_node_in_group("RemotePlayers_%d" % id)
		if node and is_instance_valid(node):
			if "_is_dead_dummy" in node and not node._is_dead_dummy:
				return false
			elif not ("_is_dead_dummy" in node) and node.modulate.a > 0.5:
				return false
	return true

func _show_exit_button() -> void:
	if not back_button or back_button.visible:
		return
	back_button.visible = true
	back_button.position.y = -150
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(back_button, "position:y", back_button_final_pos.y, button_slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _enable_spectator() -> void:
	var sm = get_tree().get_first_node_in_group("SpectatorManager")
	if sm != null and sm.has_method("start_spectating"):
		sm.start_spectating()

func _set_game_pause(v: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		return
	get_tree().paused = v

func _wave_clear_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var pickups = get_tree().get_nodes_in_group("pickup")
	var player_pos = global_position
	var to_clear = []
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			to_clear.append({"node": enemy, "dist": player_pos.distance_to(enemy.global_position)})
	for pickup in pickups:
		if pickup and is_instance_valid(pickup):
			to_clear.append({"node":pickup,"dist":player_pos.distance_to(pickup.global_position)})
	if is_instance_valid(target_point):
		to_clear.append({"node": target_point, "dist": 0.0})
	if is_instance_valid(particles):
		to_clear.append({"node": particles, "dist": 0.0})
	to_clear.sort_custom(func(a, b): return a.dist < b.dist)
	for data in to_clear:
		var node = data.node
		var dist = data.dist
		var delay = dist / enemy_wave_speed
		var node_tw = node.create_tween()
		node_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		node_tw.tween_interval(delay)
		node_tw.tween_property(node, "modulate:a", 0.0, enemy_fade_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		node_tw.parallel().tween_property(node, "scale", Vector2.ZERO, enemy_fade_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		node_tw.tween_callback(node.queue_free)

func _on_timer_timeout() -> void:
	%collision.set_deferred("disabled",true)
	%collision.set_deferred("disabled",false)

func _on_selfdamage_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if not ("damage" in body):
		return
	take_damage(body.damage)
	if body.has_method("on_touch_player"):
		body.on_touch_player(self)

func gain_XP(amount):
	$SFX.stream = load("res://resourse/audio/XP_pickup.wav")
	$SFX.pitch_scale=randf_range(0.7,1.3)
	$SFX.play()
	XP+=amount*growth
	total_XP+=amount*growth

func check_XP():
	if XP>%XP.max_value:
		XP-=%XP.max_value
		$SFX.stream = load("res://resourse/audio/level_up.wav")
		$SFX.pitch_scale=randf_range(0.7,1.3)
		$SFX.play()
		level+=1

func _on_magnet_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.has_method("follow"):
		area.follow(self)

func gain_microchips(amount):
	microchips+=amount

func _on_dash_cooldown_timeout() -> void:
	can_dash=true
	%TargetPoint.modulate = Color("8e00e0")

func open_card():
	$UI/Card.open_check()

func _on_button_texture_mouse_entered() -> void:
	$UI/Card/Open/Button_Texture.texture=preload("res://sprites/button_ui_pressedi.png")
	$UI/Card/Close/Button_Texture.texture=preload("res://sprites/button_ui_pressedi.png")

func _on_button_texture_mouse_exited() -> void:
	$UI/Card/Open/Button_Texture.texture=preload("res://sprites/button_ui.png")
	$UI/Card/Close/Button_Texture.texture=preload("res://sprites/button_ui.png")

func set_base_stats(base_stats:Stats):
	max_health += base_stats.max_health
	recovery += base_stats.recovery
	armor += base_stats.armor
	movement_speed += base_stats.movement_speed
	might += base_stats.might
	area += base_stats.area
	magnet += base_stats.magnet
	growth += base_stats.growth
	luck += base_stats.luck
	health=max_health
