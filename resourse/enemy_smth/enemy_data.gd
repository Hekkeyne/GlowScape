class_name EnemyData
extends Resource
@export_group("Параметры")
@export var title: String = "Имя"
@export_range(1.0, 1000.0, 1.0) var max_health: float = 10.0
@export_range(1.0, 100.0, 1.0) var damage: float = 5.0
@export_range(0.0, 500.0, 5.0) var speed: float = 125.0
@export var can_be_elite: bool = true
@export_group("Визуал")
@export var visual_scene: PackedScene
@export var fallback_texture: Texture2D
@export_group("Поведение")
@export var ai_behavior: EnemyAIBehavior
@export_range(100.0, 2000.0, 50.0) var despawn_distance: float = 1100.0
@export_group("Дроп")
@export var drops: Array[Resource] = []
@export var elite_guaranteed_drop: Resource
@export_group("Описание")
@export_multiline var description: String = ""
static func pick_weighted(drops: Array[Resource]) -> Resource:
	if drops.is_empty():
		return null
	var total_weight: float = 0.0
	for drop in drops:
		if drop is Pickups:
			total_weight += drop.weight
		else:
			total_weight += 1.0
	if total_weight <= 0.0:
		return drops.pick_random()
	var roll = randf() * total_weight
	var accumulated: float = 0.0
	for drop in drops:
		var w: float = drop.weight if drop is Pickups else 1.0
		accumulated += w
		if roll <= accumulated:
			return drop
	return drops.back()
