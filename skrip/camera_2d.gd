extends Camera2D

# Batas atas kamera
@export var top_limit_y: float = 375.0

# Batas horizontal kamera
@export var left_limit_x: float = 0.0
@export var right_limit_x: float = 1152.0

func _ready() -> void:
	# Kamera lepas dari transform parent
	top_level = true

func _process(delta: float) -> void:
	var target = get_parent()

	if target and target is Node2D:
		# Ikuti posisi X target, tapi dibatasi kiri dan kanan
		global_position.x = clamp(target.global_position.x, left_limit_x, right_limit_x)

		# Ikuti posisi Y target, tapi jangan melewati batas atas
		global_position.y = max(top_limit_y, target.global_position.y)
