class_name LaserEmitter
extends Node2D

@onready var shot: CPUParticles2D = $Shot
@onready var fly: CPUParticles2D = $Fly

func _ready() -> void :
	if shot:
		shot.emitting = false
	if fly:
		fly.emitting = false

func play_shot() -> void :
	if shot:
		shot.emitting = true

func set_flying(on: bool) -> void :
	if fly:
		fly.emitting = on
