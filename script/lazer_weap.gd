extends Weapon
class_name LaserWeapon

@export var beam_scene: PackedScene
@export var emitter_scene: PackedScene
@export var emitter_texture: Texture2D
@export_range(1, 100) var laser_count: int = 1
@export_range(0, 8) var max_reflections: int = 2
@export_range(0.1, 10, 0.1) var beam_duration: float = 0.4
@export_range(0.02, 5, 0.02) var grow_time: float = 0.12
@export_range(1, 8) var star_count: int = 1
@export_range(-6.0, 6.0, 0.5) var star_spin: float = 0.0
@export_range(30.0, 150.0, 5.0) var crown_radius: float = 60.0
@export_range(60.0, 300.0, 10.0) var deploy_radius: float = 140.0
@export_range(1.0, 20.0, 0.5) var aim_speed: float = 8.0
@export_range(0.05, 0.6, 0.05) var freeze_time: float = 0.2
@export_range(10.0, 200.0, 5.0) var crown_stiffness: float = 70.0
@export_range(20.0, 400.0, 10.0) var dive_stiffness: float = 110.0
@export_range(1.0, 30.0, 0.5) var spring_damping: float = 13.0
@export_range(0.0, 600.0, 25.0) var launch_impulse: float = 200.0
@export_range(0.0, 800.0, 25.0) var recoil_force: float = 180.0
@export_range(0.0, 20.0, 0.5) var bob_amp: float = 4.0
@export_range(0.5, 10.0, 0.5) var bob_freq: float = 3.0
@export_range(0.0, 2.0, 0.05) var rehit_interval: float = 0.0
@export_range(1.0, 20.0, 0.5) var side_swing_speed: float = 8.0
@export_range(0.6, 3.1416, 0.05) var crown_span: float = 3.1416
var rig: LaserEmitters = null

func activate(source, _target, scene_tree):
	if source == null or not is_instance_valid(source):
		return
	if scene_tree == null or scene_tree.current_scene == null:
		return
	if scene_tree.paused:
		return
	if not is_instance_valid(rig):
		rig = LaserEmitters.new()
		rig.init_rig(self, source)
		scene_tree.current_scene.add_child(rig)

func update(_delta: float) -> void :
	pass

func upgrade_item():
	if max_level_reached():
		try_evolve()
		return
	if not is_upgradable():
		return
	var upgrade = upgrades[level - 1]
	if "damage" in upgrade:
		damage += upgrade.damage
	if "cooldown" in upgrade:
		cooldown += upgrade.cooldown
	if "reflections" in upgrade:
		max_reflections += upgrade.reflections
	if "lasers" in upgrade:
		laser_count += upgrade.lasers
	level += 1

func reset():
	if is_instance_valid(rig):
		rig.queue_free()
	rig = null
