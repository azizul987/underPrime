extends CharacterBody2D

@export var speed: float = 240.0
@export var tilt_speed: float = 8.0
@export var max_tilt: float = 25.0

@export var gravity: float = 400.0
@export var surface_level: float = 375.0

@export var sprite: Sprite2D

func _physics_process(delta: float) -> void:
	if not sprite:
		return

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Kecepatan horizontal (kiri/kanan) selalu jalan
	velocity.x = input_dir.x * speed
	
	# 1. Logika Permukaan Air dan Gravitasi
	if global_position.y < surface_level:
		# Kalau terlanjur di atas air (misal jatuh dari titik spawn), tarik ke bawah
		velocity.y += gravity * delta 
	else:
		# Kalau di dalam air, ikuti input naik/turun
		velocity.y = input_dir.y * speed

	# INI KUNCINYA: Mencegah atraksi lumba-lumba
	if global_position.y <= surface_level and velocity.y < 0:
		velocity.y = 0 # Matikan momentum ke atas seketika
		global_position.y = surface_level # Kunci posisinya pas di permukaan air
	
	# 2. Logika Hadap Kiri/Kanan
	if input_dir.x != 0:
		sprite.flip_h = input_dir.x < 0
		
	# 3. Logika Rotasi (Otomatis mendatar saat di permukaan karena velocity.y jadi 0)
	var target_rotation := 0.0
	
	if velocity.y < 0:
		target_rotation = -max_tilt
	elif velocity.y > 0:
		target_rotation = max_tilt
		
	if sprite.flip_h:
		target_rotation = -target_rotation
		
	sprite.rotation_degrees = lerp(sprite.rotation_degrees, target_rotation, tilt_speed * delta)
	
	move_and_slide()
