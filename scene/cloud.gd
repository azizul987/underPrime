extends Node2D

@export var speed: float = 200.0
@export var clouds: Array[Sprite2D]

@export var left_marker: Marker2D
@export var right_marker: Marker2D

func _process(delta: float) -> void:
	if left_marker == null or right_marker == null:
		return

	for cloud in clouds:
		if cloud == null:
			continue

		cloud.position.x -= speed * delta

		if cloud.position.x <= left_marker.position.x:
			cloud.position.x = right_marker.position.x
