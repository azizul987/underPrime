@onready var layer = $TileMapLayer

func _ready():
	var rect = layer.get_used_rect()
	print("Lebar tile:", rect.size.x)
	print("Tinggi tile (vertikal):", rect.size.y)
