extends Area2D

@export var fish_id: String = ""

@onready var sprite_2d: Sprite2D = $Sprite2D

var fish_data: Dictionary = {}
var scanned: bool = false


func _ready() -> void:
	add_to_group("fish")
	fish_data = GameData.get_fish_data_by_id(fish_id)
	_apply_fish_visual()


func _apply_fish_visual() -> void:
	if fish_data.is_empty():
		push_warning("Data ikan kosong untuk id: " + fish_id)
		return

	if not fish_data.has("sprite_path"):
		push_warning("sprite_path tidak ada untuk id: " + fish_id)
		return

	var texture: Texture2D = load(fish_data["sprite_path"]) as Texture2D
	if texture == null:
		push_warning("Texture gagal diload: " + str(fish_data["sprite_path"]))
		return

	sprite_2d.texture = texture


func scan_fish() -> int:
	if scanned:
		return 0

	scanned = true
	var reward: int = GameData.collect_fish(fish_id)
	queue_free()
	return reward
