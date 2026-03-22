extends CharacterBody2D

@export var speed: float = 240.0
@export var tilt_speed: float = 8.0
@export var max_tilt: float = 25.0
@export var gravity: float = 400.0

@export var surface_level_y: float = 375.0
@export var sea_floor_depth: float = 5056.0

@export var sprite: AnimatedSprite2D
@export var pressure_label: RichTextLabel
@export var depth_label: RichTextLabel

# false = sprite asli menghadap kanan
# true  = sprite asli menghadap kiri
@export var sprite_faces_left: bool = true

const SURFACE_PRESSURE := 101325.0
const SEA_WATER_DENSITY := 1025.0
const WATER_GRAVITY := 9.81

var current_depth: float = 0.0
var current_pressure: float = 0.0
var current_pressure_normalized: float = 0.0
var current_depth_percent: float = 0.0

var _last_printed_depth: float = -1.0
var _last_printed_pressure: float = -1.0
var _last_printed_pressure_normalized: float = -1.0


func _physics_process(delta: float) -> void:
	if not _is_ready_to_move():
		return

	var input_dir := _get_input_direction()

	_apply_horizontal_movement(input_dir)
	_apply_vertical_movement(input_dir, delta)
	_prevent_leaving_surface()

	_update_sprite_direction(input_dir)
	_update_sprite_rotation(delta)

	move_and_slide()

	_update_ocean_state()
	_update_ui()

	if _is_moving(input_dir):
		_print_ocean_state_if_changed()


func _is_ready_to_move() -> bool:
	return sprite != null


func _get_input_direction() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func _is_moving(input_dir: Vector2) -> bool:
	return input_dir != Vector2.ZERO


func _apply_horizontal_movement(input_dir: Vector2) -> void:
	velocity.x = input_dir.x * speed


func _apply_vertical_movement(input_dir: Vector2, delta: float) -> void:
	if _is_above_surface():
		velocity.y += gravity * delta
	else:
		velocity.y = input_dir.y * speed


func _prevent_leaving_surface() -> void:
	if global_position.y <= surface_level_y and velocity.y < 0.0:
		velocity.y = 0.0
		global_position.y = surface_level_y


func _update_sprite_direction(input_dir: Vector2) -> void:
	if input_dir.x == 0.0:
		return

	var moving_left := input_dir.x < 0.0

	if sprite_faces_left:
		sprite.flip_h = not moving_left
	else:
		sprite.flip_h = moving_left


func _update_sprite_rotation(delta: float) -> void:
	var target_rotation := _get_target_rotation()

	if _is_sprite_visually_facing_left():
		target_rotation = -target_rotation

	sprite.rotation_degrees = lerp(
		sprite.rotation_degrees,
		target_rotation,
		tilt_speed * delta
	)


func _get_target_rotation() -> float:
	if velocity.y < 0.0:
		return -max_tilt
	elif velocity.y > 0.0:
		return max_tilt
	return 0.0


func _is_sprite_visually_facing_left() -> bool:
	if sprite_faces_left:
		return not sprite.flip_h
	else:
		return sprite.flip_h


func _update_ocean_state() -> void:
	current_depth = get_depth()
	current_pressure = get_pressure()
	current_pressure_normalized = get_pressure_normalized()
	current_depth_percent = get_depth_percent()


func _update_ui() -> void:
	if pressure_label:
		pressure_label.text = "[b]Pressure:[/b] " + str(snapped(current_pressure, 0.01)) + " Pa"

	if depth_label:
		depth_label.text = "[b]Depth:[/b] " + str(snapped(current_depth, 0.01)) + " m"


func _print_ocean_state_if_changed() -> void:
	if (
		is_equal_approx(current_depth, _last_printed_depth)
		and is_equal_approx(current_pressure, _last_printed_pressure)
		and is_equal_approx(current_pressure_normalized, _last_printed_pressure_normalized)
	):
		return

	print("Depth: ", snapped(current_depth, 0.01), " m")
	print("Pressure raw: ", snapped(current_pressure, 0.01), " Pa")
	print("Pressure normalized: ", snapped(current_pressure_normalized, 0.001))
	print("Depth percent: ", snapped(current_depth_percent * 100.0, 0.01), "%")
	print("------")

	_last_printed_depth = current_depth
	_last_printed_pressure = current_pressure
	_last_printed_pressure_normalized = current_pressure_normalized


func _is_above_surface() -> bool:
	return global_position.y < surface_level_y


func get_depth() -> float:
	return clamp(global_position.y - surface_level_y, 0.0, sea_floor_depth)


func get_pressure() -> float:
	return SURFACE_PRESSURE + SEA_WATER_DENSITY * WATER_GRAVITY * get_depth()


func get_max_pressure() -> float:
	return SURFACE_PRESSURE + SEA_WATER_DENSITY * WATER_GRAVITY * sea_floor_depth


func get_pressure_normalized() -> float:
	var min_pressure := SURFACE_PRESSURE
	var max_pressure := get_max_pressure()

	if is_equal_approx(min_pressure, max_pressure):
		return 0.0

	return clamp(
		(current_pressure - min_pressure) / (max_pressure - min_pressure),
		0.0,
		1.0
	)


func get_depth_percent() -> float:
	if sea_floor_depth <= 0.0:
		return 0.0
	return get_depth() / sea_floor_depth
