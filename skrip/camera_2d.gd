extends Camera2D

# Batas atas kamera (permukaan air)
@export var top_limit_y: float = 375.0

# Posisi tengah X dari scene kamu (ubah angkanya di Inspector!)
# Misalnya kalau resolusi game kamu 1152x648, nilai tengahnya adalah 576
@export var fixed_scene_x: float = 576.0 

func _ready() -> void:
	# Bikin kamera lepas dari tarikan kapal selam
	top_level = true
	
	# Langsung set posisi X kamera ke tengah scene yang kamu inginkan
	global_position.x = fixed_scene_x

func _process(delta: float) -> void:
	var target = get_parent()
	
	if target and target is Node2D:
		# 1. Kunci posisi X di titik tengah scene yang sudah kamu tentukan
		global_position.x = fixed_scene_x
		
		# 2. Ikuti Y kapal selam, tapi batasi supaya gak naik melewati 375
		# Di Godot 2D, posisi atas itu nilainya kecil, jadi kita pakai max()
		# supaya kalau kapal di Y=200, kamera tetap ambil 375.
		global_position.y = max(top_limit_y, target.global_position.y)
