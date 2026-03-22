extends CharacterBody2D

@export var fish_id: String = ""
@export var move_speed: float = 50.0
@export var move_distance: float = 120.0
@export var start_moving_left: bool = false

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var raycast_left: RayCast2D = $RayCastLeft
@onready var raycast_right: RayCast2D = $RayCastRight

var fish_data: Dictionary = {}
var scanned: bool = false

var start_position: Vector2 = Vector2.ZERO
var move_direction: int = 1


func _ready() -> void:
	add_to_group("fish")

	fish_data = GameData.get_fish_data_by_id(fish_id)
	_apply_fish_visual()

	start_position = global_position

	if start_moving_left:
		move_direction = -1
	else:
		move_direction = 1

	_update_sprite_flip()


func _physics_process(_delta: float) -> void:
	_update_movement()
	move_and_slide()


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


func _update_movement() -> void:
	if _should_turn_around():
		_flip_direction()

	velocity.x = move_direction * move_speed
	velocity.y = 0.0


func _should_turn_around() -> bool:
	var offset_x: float = global_position.x - start_position.x

	if move_direction < 0 and offset_x <= -move_distance:
		return true

	if move_direction > 0 and offset_x >= move_distance:
		return true

	if move_direction < 0 and raycast_left.is_colliding():
		return true

	if move_direction > 0 and raycast_right.is_colliding():
		return true

	if is_on_wall():
		return true

	return false


func _flip_direction() -> void:
	move_direction *= -1
	_update_sprite_flip()


func _update_sprite_flip() -> void:
	sprite_2d.flip_h = move_direction < 0


func scan_fish() -> int:
	if scanned:
		return 0

	scanned = true
	var reward: int = GameData.collect_fish(fish_id)
	queue_free()
	return reward 
