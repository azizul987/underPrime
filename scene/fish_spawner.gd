extends Node2D

@export var fish_scene: PackedScene
@export var player_path: NodePath
@export var obstacle_layer_path: NodePath

@export var spawn_count_current_stage: int = 12
@export var spawn_count_next_stage: int = 8

@export var spawn_x_min: float = 100.0
@export var spawn_x_max: float = 1200.0

@export var surface_level_y: float = 375.0
@export var sea_floor_depth: float = 5056.0

@export var max_spawn_attempts: int = 100
@export var fish_spacing: float = 16.0

var current_stage_seen: int = -1
var spawned_stages: Array[int] = []

@onready var player: CharacterBody2D = get_node(player_path) as CharacterBody2D
@onready var obstacle_layer: TileMapLayer = get_node_or_null(obstacle_layer_path) as TileMapLayer


func _ready() -> void:
	randomize()

	if player == null:
		push_warning("Player tidak ditemukan pada player_path")
		return

	current_stage_seen = player.current_stage
	_spawn_current_and_next_stage(current_stage_seen)


func _process(_delta: float) -> void:
	if player == null:
		return

	var stage_now: int = player.current_stage

	if stage_now != current_stage_seen:
		current_stage_seen = stage_now
		_spawn_current_and_next_stage(stage_now)


func _spawn_current_and_next_stage(stage_now: int) -> void:
	_spawn_stage_if_needed(stage_now, spawn_count_current_stage)

	var next_stage: int = min(stage_now + 1, 6)
	if next_stage != stage_now:
		_spawn_stage_if_needed(next_stage, spawn_count_next_stage)


func _spawn_stage_if_needed(stage: int, amount: int) -> void:
	if spawned_stages.has(stage):
		return

	spawn_fish_for_stage(stage, amount)
	spawned_stages.append(stage)


func spawn_fish_for_stage(stage: int, amount: int) -> void:
	var fish_list: Array = GameData.get_fish_by_stage(stage)

	if fish_list.is_empty():
		print("Tidak ada ikan di stage ", stage)
		return

	var stage_y_range: Vector2 = _get_stage_world_y_range(stage)
	var success_count: int = 0

	for i in range(amount):
		var spawn_result: Dictionary = _find_valid_spawn_position_in_stage(stage_y_range)

		if not bool(spawn_result["success"]):
			continue

		var spawn_pos: Vector2 = spawn_result["position"] as Vector2
		var random_index: int = randi() % fish_list.size()
		var fish_data: Dictionary = fish_list[random_index]

		var fish_instance: CharacterBody2D = fish_scene.instantiate() as CharacterBody2D
		if fish_instance == null:
			push_warning("fish_scene tidak menghasilkan CharacterBody2D")
			return

		fish_instance.fish_id = fish_data["id"]
		fish_instance.global_position = spawn_pos
		add_child(fish_instance)

		success_count += 1

	print("Stage ", stage, " spawn berhasil ", success_count, " ikan")


func _get_stage_world_y_range(stage: int) -> Vector2:
	var depth_min: float = 0.0
	var depth_max: float = 0.0

	match stage:
		1:
			depth_min = 0.0
			depth_max = 800.0
		2:
			depth_min = 800.0
			depth_max = 1600.0
		3:
			depth_min = 1600.0
			depth_max = 2400.0
		4:
			depth_min = 2400.0
			depth_max = 3200.0
		5:
			depth_min = 3200.0
			depth_max = 4200.0
		6:
			depth_min = 4200.0
			depth_max = sea_floor_depth
		_:
			depth_min = 0.0
			depth_max = 800.0

	return Vector2(
		surface_level_y + depth_min,
		surface_level_y + depth_max
	)


func _find_valid_spawn_position_in_stage(stage_y_range: Vector2) -> Dictionary:
	for i in range(max_spawn_attempts):
		var test_pos: Vector2 = Vector2(
			randf_range(spawn_x_min, spawn_x_max),
			randf_range(stage_y_range.x, stage_y_range.y)
		)

		if _is_spawn_position_valid(test_pos):
			return {
				"success": true,
				"position": test_pos
			}

	return {
		"success": false,
		"position": Vector2.ZERO
	}


func _is_spawn_position_valid(world_pos: Vector2) -> bool:
	if obstacle_layer != null:
		var local_pos: Vector2 = obstacle_layer.to_local(world_pos)
		var cell_coords: Vector2i = obstacle_layer.local_to_map(local_pos)
		var tile_data: TileData = obstacle_layer.get_cell_tile_data(cell_coords)

		if tile_data != null:
			return false

	for child: Node in get_children():
		if child.is_in_group("fish") and child is Node2D:
			var other_fish: Node2D = child as Node2D
			if other_fish.global_position.distance_to(world_pos) < fish_spacing:
				return false

	return true


func clear_fish() -> void:
	for child: Node in get_children():
		if child.is_in_group("fish"):
			child.queue_free()


func clear_stage_memory() -> void:
	spawned_stages.clear()
