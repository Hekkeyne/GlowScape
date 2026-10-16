class_name GunnerAI
extends EnemyAIBehavior

@export_range(100.0, 1000.0, 50.0) var shoot_range: float = 550.0
@export_range(0.5, 5.0, 0.25) var fire_interval: float = 2.0
@export_range(1, 6) var burst_count: int = 3
@export_range(0.05, 1.0, 0.05) var burst_interval: float = 0.3
@export_range(0.05, 1.0, 0.05) var windup_time: float = 0.5
@export_range(0.05, 1.0, 0.05) var stop_time: float = 0.5
@export_range(0.1, 1.5, 0.1) var lean_angle: float = 0.6
@export var projectile_scene: PackedScene
@export var teleport_scene: PackedScene
@export_range(0.3, 20.0, 0.1) var tp_life_min: float = 0.7
@export_range(0.3, 20.0, 0.1) var tp_life_max: float = 1.4

var teleport_pending: bool = false
var pending_timer: float = 0.0
enum State{NORMAL, WINDUP, SPIN, STOP}
var state: int = State.NORMAL
var fire_timer: float = 0.0
var spin_dir: float = 1.0
var spin_timer: float = 0.0
var spin_duration: float = 0.0
var spin_angle: float = 0.0
var spin_start_rotation: float = 0.0
var windup_start_rotation: float = 0.0
var windup_timer: float = 0.0
var stop_timer: float = 0.0
var shots_done: int = 0

func calculate_movement(enemy: CharacterBody2D, player: Node2D, delta: float) -> Vector2:
	var e = enemy as EnemyBase
	if not e or not is_instance_valid(player):
		return Vector2.ZERO
	if teleport_pending:
		pending_timer += delta
		e.modulate.a = 0.55 + sin(pending_timer * 12.0) * 0.2
	var to_player = player.global_position - e.global_position
	var distance = to_player.length()
	var direction = to_player.normalized()
	match state:
		State.NORMAL:
			enemy.play_anim("close")
			if e.has_method("set_separation"):
				e.set_separation(distance)
			fire_timer += delta
			if fire_timer >= fire_interval and distance <= shoot_range:
				fire_timer = 0.0
				state = State.WINDUP
				windup_timer = 0.0
				spin_dir = 1.0 if randf() < 0.5 else -1.0
				windup_start_rotation = e.rotation
			return Vector2.ZERO
		State.WINDUP:
			enemy.play_anim("open")
			windup_timer += delta
			var wp = clampf(windup_timer / windup_time, 0.0, 1.0)
			e.rotation = windup_start_rotation - spin_dir * lean_angle * (wp * wp)
			if wp >= 1.0:
				state = State.SPIN
				spin_timer = 0.0
				spin_angle = 0.0
				shots_done = 0
				spin_duration = burst_count * burst_interval
				spin_start_rotation = e.rotation
			return Vector2.ZERO
		State.SPIN:
			spin_timer += delta
			var p = clampf(spin_timer / spin_duration, 0.0, 1.0)
			var eased = p * p * (3.0 - 2.0 * p)
			spin_angle = burst_count * TAU * eased
			e.rotation = spin_start_rotation + spin_angle * spin_dir
			while shots_done < int(spin_angle / TAU) and shots_done < burst_count:
				_shoot(e, player)
				shots_done += 1
			if p >= 1.0:
				state = State.STOP
				stop_timer = 0.0
				_shoot_teleport(e)
			return Vector2.ZERO
		State.STOP:
			enemy.play_anim("close")
			stop_timer += delta
			if stop_timer >= stop_time:
				state = State.NORMAL
			return Vector2.ZERO
	return Vector2.ZERO

func _shoot_teleport(e: EnemyBase) -> void :
	if not teleport_scene:
		return
	var p = teleport_scene.instantiate()
	p.direction = Vector2.RIGHT.rotated(randf() * TAU)
	p.lifetime = randf_range(tp_life_min, tp_life_max)
	p.caster = e
	p.global_position = e.global_position
	e.get_tree().current_scene.add_child(p)
	teleport_pending = true
	pending_timer = 0.0

func on_teleported(e: EnemyBase) -> void :
	teleport_pending = false
	pending_timer = 0.0
	e.modulate.a = 1.0

func _shoot(e: EnemyBase, player: Node2D) -> void :
	if not projectile_scene:
		return
	var p = projectile_scene.instantiate()
	p.direction = (player.global_position - e.global_position).normalized()
	p.target = player
	p.damage = e.damage
	p.curve = randf_range(-6.0, 6.0)
	p.global_position = e.global_position
	e.get_tree().current_scene.add_child(p)
