extends Sprite2D

var separation: float
var frame_counter = 0
var health: float = 10:
	set(value):
		health = value
		if health <= 0 and not is_dying:
			drop_item()
@onready var player_ref = get_tree().current_scene.find_child("player")
var drop_node = preload("res://scene/pickup.tscn")
@export var drops: Array[Pickups]
var is_dying: bool = false

func _physics_process(_delta: float) -> void :
	if not is_in_group("Destructible"):
		add_to_group("Destructible")
	frame_counter += 1
	if frame_counter >= 6:
		frame_counter = 0
		frame = (frame + 1) % (hframes * vframes)
	separation = (player_ref.position - position).length()
	if separation < player_ref.nearest_enemy_distance:
		player_ref.nearest_enemy = self
	add_to_group("Enemy")

func get_weighted_chance(weight, index):
	var sum = 0
	for i in range(weight.size()):
		sum += weight[i]
	var cumulative = 0
	for i in range(index + 1):
		cumulative += weight[i]
	return float(cumulative) / sum

func take_damage(amount = 1):
	if is_dying:
		return
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0), 0.1)
	tween.chain().tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	tween.bind_node(self)
	health -= amount

func drop_item():
	if is_dying:
		return
	is_dying = true
	var item
	var weights = []
	for pickup in drops:
		if pickup is Microchips:
			weights.append(pickup.weight)
		else:
			weights.append(pickup.weight * player_ref.luck)
	var chance = randf()
	for i in range(drops.size()):
		if chance < get_weighted_chance(weights, i):
			item = drops[i]
			break
	var item_to_drop = drop_node.instantiate()
	item_to_drop.type = item
	item_to_drop.position = position
	item_to_drop.player_ref = player_ref
	get_tree().current_scene.call_deferred("add_child", item_to_drop)
	queue_free()
