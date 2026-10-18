extends CharacterBody2D

signal died

var might: float = 1.0
var area: float = 0.0
var luck: float = 1.0
var growth: float = 0.0
var recovery: float = 0.0
var armor: float = 0.0
var magnet: float = 0.0
var movement_speed: float = 220.0
var max_health: float = 100.0
var health: float = 100.0
var level: int = 5
var microchips: int = 0
var XP: float = 0.0
var total_XP: float = 0.0
var nearest_enemy: Node2D = null
var nearest_enemy_distance: float = 9999.0
var is_dead: bool = false
var is_invincible: bool = false
var can_dash: bool = true
var character: Character = null
var weapons: Array = []
var knockback: Vector2 = Vector2.ZERO
var current_velocity: Vector2 = Vector2.ZERO
var arena: Rect2 = Rect2(-800, -600, 1600, 1200)

var _wander_dir := Vector2.RIGHT
var _wander_t := 0.0
var _invuln := 0.0
var _flee_mode := false
var _wrap_cd: float = 0.0

@export var acceleration: float = 800.0
@export var deceleration: float = 1200.0
@export var flee_speed_mult: float = 1.6
@export var flee_distance: float = 140.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var particles: CPUParticles2D = get_node_or_null("player")
@onready var target_point: Node2D = get_node_or_null("TargetPoint")

func _ready() -> void:
	add_to_group("Player")
	for child in get_children():
		if child is Area2D and child.name != "Magnet":
			if not child.body_entered.is_connected(_on_damage_area_body_entered):
				child.body_entered.connect(_on_damage_area_body_entered)
	var mag = get_node_or_null("Magnet")
	if mag:
		mag.monitoring = false
	health = max_health

func setup(p_character: Character, p_weapons: Array) -> void:
	character = p_character
	weapons = p_weapons
	if character != null and sprite != null and character.texture != null:
		sprite.texture = character.texture
	if sprite:
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
	might = randf_range(0.9, 2.2)
	luck = randf_range(1.0, 3.0)
	movement_speed = randf_range(200.0, 280.0)
	area = randf_range(150.0, 300.0)
	health = max_health
	is_dead = false
	is_invincible = false
	knockback = Vector2.ZERO
	current_velocity = Vector2.ZERO
	_fill_weapon_slots()

func _fill_weapon_slots() -> void:
	var weapons_node = get_node_or_null("UI/weapons")
	if weapons_node == null:
		return
	if weapons.is_empty():
		weapons_node.visible = false
		return
	weapons_node.visible = true
	for child in weapons_node.get_children():
		child.visible = false
		child.item = null
	var slot_scene = preload("res://scene/slot.tscn")
	for i in range(weapons.size()):
		var w = weapons[i]
		if w == null:
			continue
		var slot
		if i < weapons_node.get_child_count():
			slot = weapons_node.get_child(i)
		else:
			slot = slot_scene.instantiate()
			weapons_node.add_child(slot)
		slot.item = w
		slot.visible = true
		var timer = slot.get_node_or_null("cooldown")
		if timer:
			timer.one_shot = false
			if slot.is_inside_tree():
				timer.start()
			else:
				timer.autostart = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_wrap_cd = maxf(_wrap_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	knockback = knockback.move_toward(Vector2.ZERO, 400.0 * delta)
	_update_nearest()
	_update_flee_mode()
	var direction := _calculate_direction(delta)
	var speed_mult = flee_speed_mult if _flee_mode else 1.0
	var target_velocity = direction * movement_speed * speed_mult
	if direction != Vector2.ZERO:
		current_velocity = current_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration * delta)
	velocity = current_velocity + knockback
	move_and_slide()
	_wrap_position()
	_animate_squash(direction, delta)
	_rotate_sprite(direction, delta)
	health += recovery * delta

func _update_nearest() -> void:
	nearest_enemy = null
	nearest_enemy_distance = 9999.0
	for e in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(e) or ("is_dying" in e and e.is_dying):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < nearest_enemy_distance:
			nearest_enemy_distance = d
			nearest_enemy = e
	nearest_enemy_distance = sqrt(nearest_enemy_distance)

func _update_flee_mode() -> void:
	_flee_mode = is_instance_valid(nearest_enemy) and nearest_enemy_distance < flee_distance

func _calculate_direction(delta: float) -> Vector2:
	if _flee_mode and is_instance_valid(nearest_enemy):
		var away = (global_position - nearest_enemy.global_position).normalized()
		var edge := 120.0
		var to_center := (arena.get_center() - global_position).normalized()
		if global_position.x < arena.position.x + edge or global_position.x > arena.end.x - edge:
			away = away.lerp(Vector2(to_center.x, 0.0).normalized(), 0.8) if to_center.x != 0.0 else away
		if global_position.y < arena.position.y + edge or global_position.y > arena.end.y - edge:
			away = away.lerp(Vector2(0.0, to_center.y).normalized(), 0.8) if to_center.y != 0.0 else away
		return away.normalized()
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.0)
		if is_instance_valid(nearest_enemy):
			var to_enemy = (nearest_enemy.global_position - global_position).normalized()
			_wander_dir = to_enemy.rotated(randf_range(-0.6, 0.6))
		else:
			_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	return _wander_dir

func _animate_squash(direction: Vector2, delta: float) -> void:
	if sprite == null:
		return
	var target_scale = Vector2(1.1, 0.9) if direction != Vector2.ZERO else Vector2.ONE
	sprite.scale = sprite.scale.lerp(target_scale, 15.0 * delta)
	if particles:
		particles.emitting = direction != Vector2.ZERO

func _rotate_sprite(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO or sprite == null:
		return
	var target_angle = direction.angle()
	sprite.rotation = lerp_angle(sprite.rotation, target_angle, 20.0 * delta)
	if particles:
		particles.rotation = sprite.rotation

func _wrap_position() -> void:
	if _wrap_cd > 0.0:
		global_position = global_position.clamp(arena.position, arena.end)
		return
	var pos = global_position
	var changed = false
	if pos.x < arena.position.x:
		pos.x = arena.end.x - 1.0
		changed = true
	elif pos.x > arena.end.x:
		pos.x = arena.position.x + 1.0
		changed = true
	if pos.y < arena.position.y:
		pos.y = arena.end.y - 1.0
		changed = true
	elif pos.y > arena.end.y:
		pos.y = arena.position.y + 1.0
		changed = true
	if changed:
		global_position = pos
		knockback = Vector2.ZERO
		current_velocity = Vector2.ZERO
		_wrap_cd = 2.0

func _on_damage_area_body_entered(body: Node2D) -> void:
	if is_dead or _invuln > 0.0:
		return
	if "damage" in body:
		take_damage(body.damage)
	if body.has_method("on_touch_player"):
		body.on_touch_player(self)

func take_damage(amount) -> void:
	if is_dead or is_invincible:
		return
	health -= max(amount / ((armor + 100) / 100), 0)
	_invuln = 0.5
	if health <= 0.0:
		_die()

func apply_knockback(amount: Vector2) -> void:
	knockback += amount

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.4)
	died.emit()

func gain_XP(_amount) -> void:
	pass

func gain_microchips(_amount) -> void:
	pass
