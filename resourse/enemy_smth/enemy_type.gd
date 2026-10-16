class_name Enemy
extends Resource
@export var title : String
@export var icon : Texture2D
@export var texture : Texture2D
@export var health : float
@export var damage : float
@export var drops: Array[Pickups]
@export_multiline var description : String
@export_group("Дополнительно")
@export_range(0.0, 500.0, 5.0) var speed: float = 125.0
@export var can_be_elite: bool = true
@export var scene: PackedScene        
@export var ai_behavior: EnemyAIBehavior
@export_range(100.0, 2000.0, 50.0) var despawn_distance: float = 2000.0
@export var elite_guaranteed_drop: Pickups
@export var max_count: int = 0
static func pick_weighted(drops: Array[Pickups]) -> Pickups:
	if drops.is_empty():
		return null
	var total_weight: float = 0.0
	for drop in drops:
		total_weight += drop.weight
	if total_weight <= 0.0:
		return drops.pick_random()
	var roll = randf() * total_weight
	var accumulated: float = 0.0
	for drop in drops:
		accumulated += drop.weight
		if roll <= accumulated:
			return drop
	return drops.back()
