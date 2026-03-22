extends CharacterBody2D

@export var base_speed: float = 240.0
@export var tilt_speed: float = 8.0
@export var max_tilt: float = 25.0
@export var gravity: float = 400.0

@export var surface_level_y: float = 375.0
@export var sea_floor_depth: float = 5056.0

@export var sprite: AnimatedSprite2D
@export var pressure_label: RichTextLabel
@export var depth_label: RichTextLabel
@export var stage_label: RichTextLabel
@export var coin_label: RichTextLabel
@export var collection_label: RichTextLabel
@export var oxygen_label: RichTextLabel

@export var oxygen_upgrade_label: RichTextLabel
@export var pressure_upgrade_label: RichTextLabel
@export var propeller_upgrade_label: RichTextLabel
@export var upgrade_hint_label: RichTextLabel
@export var warning_label: RichTextLabel
@export var how_to_play_label: RichTextLabel

@export var scan_radius: float = 100.0

# Oxygen base stats
@export var base_max_oxygen: float = 100.0
@export var refill_wait_time: float = 2.0

# Emergency before death
@export var base_danger_countdown_duration: float = 10.0
@export var oxygen_countdown_bonus_per_level: float = 5.0

# Upgrade bonus
@export var oxygen_tank_bonus_per_level: float = 35.0

# Death / game over
@export var main_menu_scene: PackedScene
@export var win_scene: PackedScene
@export var game_over_delay_after_explosion: float = 0.2

# Animation naming
@export var idle_animation_suffix: String = "_idle"
@export var explode_animation_suffix: String = "_ngeledak"

# false = sprite asli menghadap kanan
# true  = sprite asli menghadap kiri
@export var sprite_faces_left: bool = true

const SURFACE_PRESSURE := 101325.0
const SEA_WATER_DENSITY := 1025.0
const WATER_GRAVITY := 9.81
const MAX_UPGRADE_LEVEL := 3

var current_depth: float = 0.0
var current_pressure: float = 0.0
var current_pressure_normalized: float = 0.0
var current_depth_percent: float = 0.0
var current_stage: int = 1

# Upgrade levels
var oxygen_tank_level: int = 0
var pressure_hull_level: int = 0
var propeller_level: int = 0

# Oxygen runtime
var max_oxygen: float = 100.0
var current_oxygen: float = 100.0
var surface_refill_timer: float = 0.0

# Runtime movement
var current_speed: float = 240.0

# Emergency state
var is_in_emergency: bool = false
var emergency_timer: float = 0.0
var emergency_reason: String = ""

# Death state
var is_dead: bool = false
var is_game_over_started: bool = false
var death_reason: String = ""

# UI text
var upgrade_info_text: String = ""
var warning_text: String = ""

var _last_printed_depth: float = -1.0
var _last_printed_pressure: float = -1.0
var _last_printed_pressure_normalized: float = -1.0
var _last_printed_stage: int = -1


func _ready() -> void:
	_recalculate_oxygen_stats(true)
	_update_ocean_state()
	_update_current_speed()
	_update_warning_text()
	_update_player_visual_animation()
	_update_ui()


func _physics_process(delta: float) -> void:
	if not _is_ready_to_move():
		return

	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_ocean_state()
		_update_warning_text()
		_update_ui()
		return

	_update_ocean_state()
	_update_current_speed()

	var input_dir: Vector2 = _get_input_direction()

	_apply_horizontal_movement(input_dir)
	_apply_vertical_movement(input_dir, delta)
	_prevent_leaving_surface()

	_update_sprite_direction(input_dir)
	_update_sprite_rotation(delta)

	move_and_slide()

	_update_ocean_state()
	_update_oxygen(delta)
	_check_pressure_emergency()
	_update_emergency(delta)
	_clear_emergency_if_safe()

	_handle_upgrade_input()
	_update_current_speed()
	_update_player_visual_animation()
	_update_warning_text()
	_update_ui()
	_handle_scan_input()

	if _is_moving(input_dir):
		_print_ocean_state_if_changed()


func _is_ready_to_move() -> bool:
	return sprite != null


func _get_input_direction() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func _is_moving(input_dir: Vector2) -> bool:
	return input_dir != Vector2.ZERO


func _apply_horizontal_movement(input_dir: Vector2) -> void:
	velocity.x = input_dir.x * current_speed


func _apply_vertical_movement(input_dir: Vector2, delta: float) -> void:
	if _is_above_surface():
		velocity.y += gravity * delta
	else:
		velocity.y = input_dir.y * current_speed


func _prevent_leaving_surface() -> void:
	if global_position.y <= surface_level_y and velocity.y < 0.0:
		velocity.y = 0.0
		global_position.y = surface_level_y


func _update_sprite_direction(input_dir: Vector2) -> void:
	if input_dir.x == 0.0:
		return

	var moving_left: bool = input_dir.x < 0.0

	if sprite_faces_left:
		sprite.flip_h = not moving_left
	else:
		sprite.flip_h = moving_left


func _update_sprite_rotation(delta: float) -> void:
	var target_rotation: float = _get_target_rotation()

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
	current_stage = get_stage_from_depth(current_depth)


func _update_oxygen(delta: float) -> void:
	if is_dead:
		return

	if _is_on_surface_for_refill():
		surface_refill_timer += delta

		if surface_refill_timer >= refill_wait_time:
			current_oxygen = max_oxygen
	else:
		surface_refill_timer = 0.0

	var oxygen_drain: float = _get_oxygen_drain_per_second()
	current_oxygen = max(current_oxygen - oxygen_drain * delta, 0.0)

	if current_oxygen <= 0.0 and not is_in_emergency:
		_start_emergency("oxygen_habis")


func _is_on_surface_for_refill() -> bool:
	return global_position.y <= surface_level_y + 1.0


func _get_oxygen_drain_per_second() -> float:
	var base_drain_by_stage: float = 0.0

	match current_stage:
		1:
			base_drain_by_stage = 0.8
		2:
			base_drain_by_stage = 1.8
		3:
			base_drain_by_stage = 3.2
		4:
			base_drain_by_stage = 5.5
		5:
			base_drain_by_stage = 8.5
		6:
			base_drain_by_stage = 12.0
		_:
			base_drain_by_stage = 0.8

	var extra_from_depth: float = current_depth_percent * 3.0
	var tank_efficiency_bonus: float = float(oxygen_tank_level) * 0.18

	var efficiency_multiplier: float = max(
		0.28,
		1.0 - tank_efficiency_bonus
	)

	return (base_drain_by_stage + extra_from_depth) * efficiency_multiplier


func _recalculate_oxygen_stats(fill_to_full: bool = false) -> void:
	max_oxygen = base_max_oxygen + float(oxygen_tank_level) * oxygen_tank_bonus_per_level

	if fill_to_full:
		current_oxygen = max_oxygen
	else:
		current_oxygen = clamp(current_oxygen, 0.0, max_oxygen)


func _get_current_danger_countdown_duration() -> float:
	return base_danger_countdown_duration + float(oxygen_tank_level) * oxygen_countdown_bonus_per_level


func _get_max_safe_stage_from_pressure() -> int:
	match pressure_hull_level:
		0:
			return 1
		1:
			return 3
		2:
			return 5
		3:
			return 6
		_:
			return 1


func _check_pressure_emergency() -> void:
	var max_safe_stage: int = _get_max_safe_stage_from_pressure()

	if current_stage > max_safe_stage and not is_in_emergency:
		_start_emergency("tekanan_tidak_cukup")


func _update_current_speed() -> void:
	current_speed = _get_speed_for_current_depth()


func _get_speed_for_current_depth() -> float:
	var speed_multiplier: float = 1.0

	match current_stage:
		1:
			speed_multiplier = 1.0
		2:
			match propeller_level:
				0:
					speed_multiplier = 0.78
				1:
					speed_multiplier = 0.90
				2:
					speed_multiplier = 0.97
				3:
					speed_multiplier = 1.05
		3:
			match propeller_level:
				0:
					speed_multiplier = 0.58
				1:
					speed_multiplier = 0.76
				2:
					speed_multiplier = 0.92
				3:
					speed_multiplier = 1.02
		4:
			match propeller_level:
				0:
					speed_multiplier = 0.38
				1:
					speed_multiplier = 0.60
				2:
					speed_multiplier = 0.82
				3:
					speed_multiplier = 0.98
		5:
			match propeller_level:
				0:
					speed_multiplier = 0.24
				1:
					speed_multiplier = 0.45
				2:
					speed_multiplier = 0.70
				3:
					speed_multiplier = 0.92
		6:
			match propeller_level:
				0:
					speed_multiplier = 0.14
				1:
					speed_multiplier = 0.32
				2:
					speed_multiplier = 0.58
				3:
					speed_multiplier = 0.86
		_:
			speed_multiplier = 1.0

	return base_speed * speed_multiplier


func _can_upgrade_component(current_level: int) -> bool:
	if current_level >= MAX_UPGRADE_LEVEL:
		return false

	var target_level: int = current_level + 1

	if target_level <= 1:
		return true

	if oxygen_tank_level < target_level - 1:
		return false

	if pressure_hull_level < target_level - 1:
		return false

	if propeller_level < target_level - 1:
		return false

	return true


func _get_oxygen_upgrade_cost() -> int:
	match oxygen_tank_level:
		0:
			return 40
		1:
			return 80
		2:
			return 140
		_:
			return -1


func _get_pressure_upgrade_cost() -> int:
	match pressure_hull_level:
		0:
			return 50
		1:
			return 100
		2:
			return 170
		_:
			return -1


func _get_propeller_upgrade_cost() -> int:
	match propeller_level:
		0:
			return 45
		1:
			return 90
		2:
			return 150
		_:
			return -1


func _try_spend_coins(cost: int) -> bool:
	if cost < 0:
		return false

	if GameData.coins < cost:
		return false

	GameData.coins -= cost
	return true


func upgrade_oxygen_tank() -> bool:
	if not _can_upgrade_component(oxygen_tank_level):
		upgrade_info_text = "Gagal upgrade Oxygen: komponen lain harus level " + str(oxygen_tank_level) + " dulu"
		return false

	var cost: int = _get_oxygen_upgrade_cost()
	if not _try_spend_coins(cost):
		upgrade_info_text = "Coin kurang untuk upgrade Oxygen (" + str(cost) + ")"
		return false

	oxygen_tank_level += 1
	_recalculate_oxygen_stats(false)
	_update_player_visual_animation()
	upgrade_info_text = "Oxygen Tank naik ke level " + str(oxygen_tank_level) + " (-" + str(cost) + " coin)"
	return true


func upgrade_pressure_hull() -> bool:
	if not _can_upgrade_component(pressure_hull_level):
		upgrade_info_text = "Gagal upgrade Pressure: komponen lain harus level " + str(pressure_hull_level) + " dulu"
		return false

	var cost: int = _get_pressure_upgrade_cost()
	if not _try_spend_coins(cost):
		upgrade_info_text = "Coin kurang untuk upgrade Pressure (" + str(cost) + ")"
		return false

	pressure_hull_level += 1
	_update_player_visual_animation()
	upgrade_info_text = "Pressure Hull naik ke level " + str(pressure_hull_level) + " (-" + str(cost) + " coin)"
	return true


func upgrade_propeller() -> bool:
	if not _can_upgrade_component(propeller_level):
		upgrade_info_text = "Gagal upgrade Propeller: komponen lain harus level " + str(propeller_level) + " dulu"
		return false

	var cost: int = _get_propeller_upgrade_cost()
	if not _try_spend_coins(cost):
		upgrade_info_text = "Coin kurang untuk upgrade Propeller (" + str(cost) + ")"
		return false

	propeller_level += 1
	_update_current_speed()
	_update_player_visual_animation()
	upgrade_info_text = "Propeller naik ke level " + str(propeller_level) + " (-" + str(cost) + " coin)"
	return true


func _handle_upgrade_input() -> void:
	if is_dead:
		return

	if Input.is_action_just_pressed("upgrade_oxygen"):
		upgrade_oxygen_tank()

	if Input.is_action_just_pressed("upgrade_pressure"):
		upgrade_pressure_hull()

	if Input.is_action_just_pressed("upgrade_propeller"):
		upgrade_propeller()


func refill_oxygen_now() -> void:
	current_oxygen = max_oxygen
	surface_refill_timer = 0.0


func _start_emergency(reason: String) -> void:
	is_in_emergency = true
	emergency_reason = reason
	emergency_timer = _get_current_danger_countdown_duration()


func _update_emergency(delta: float) -> void:
	if not is_in_emergency or is_dead:
		return

	emergency_timer -= delta

	if emergency_timer <= 0.0:
		_start_game_over(emergency_reason)


func _clear_emergency_if_safe() -> void:
	if not is_in_emergency or is_dead:
		return

	match emergency_reason:
		"oxygen_habis":
			if _is_on_surface_for_refill():
				is_in_emergency = false
				emergency_reason = ""
				emergency_timer = 0.0
				current_oxygen = max(current_oxygen, max_oxygen * 0.15)
		"tekanan_tidak_cukup":
			if current_stage <= _get_max_safe_stage_from_pressure():
				is_in_emergency = false
				emergency_reason = ""
				emergency_timer = 0.0


func _start_game_over(reason: String) -> void:
	if is_game_over_started:
		return

	is_game_over_started = true
	is_dead = true
	death_reason = reason
	velocity = Vector2.ZERO

	if sprite:
		sprite.rotation_degrees = 0.0

		var explode_anim: String = _get_explode_animation_name()

		if sprite.sprite_frames and sprite.sprite_frames.has_animation(explode_anim):
			sprite.play(explode_anim)
			_wait_explosion_then_back_to_menu()
			return

	_go_to_main_menu()


func _wait_explosion_then_back_to_menu() -> void:
	await sprite.animation_finished
	await get_tree().create_timer(game_over_delay_after_explosion).timeout
	_go_to_main_menu()


func _go_to_main_menu() -> void:
	if main_menu_scene != null:
		get_tree().change_scene_to_packed(main_menu_scene)
	else:
		push_warning("main_menu_scene belum diisi di Inspector")


func _win_game() -> void:
	print("MENANG! Pohon bawah laut ditemukan dan discan.")

	if win_scene != null:
		get_tree().change_scene_to_packed(win_scene)
	else:
		print("win_scene belum diisi di Inspector.")


func _get_visual_tier() -> int:
	var shared_level: int = min(oxygen_tank_level, pressure_hull_level, propeller_level)
	return clamp(shared_level + 1, 1, 4)


func _get_idle_animation_name() -> String:
	return "level" + str(_get_visual_tier()) + idle_animation_suffix


func _get_explode_animation_name() -> String:
	return "level" + str(_get_visual_tier()) + explode_animation_suffix


func _update_player_visual_animation() -> void:
	if sprite == null:
		return

	if is_dead:
		return

	var idle_anim: String = _get_idle_animation_name()

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(idle_anim):
		if sprite.animation != idle_anim:
			sprite.play(idle_anim)


func _update_warning_text() -> void:
	if is_dead:
		match death_reason:
			"oxygen_habis":
				warning_text = "WARNING: Oxygen habis!"
			"tekanan_tidak_cukup":
				warning_text = "WARNING: Tekanan terlalu besar!"
			_:
				warning_text = "WARNING: Game Over!"
		return

	if is_in_emergency:
		match emergency_reason:
			"oxygen_habis":
				warning_text = "DARURAT: Oksigen habis! Naik ke permukaan dalam " + str(snapped(emergency_timer, 0.01)) + " detik"
			"tekanan_tidak_cukup":
				warning_text = "DARURAT: Tekanan terlalu besar! Kembali ke stage aman dalam " + str(snapped(emergency_timer, 0.01)) + " detik"
			_:
				warning_text = "DARURAT: " + str(snapped(emergency_timer, 0.01)) + " detik"
		return

	var warnings: Array[String] = []

	if current_oxygen <= max_oxygen * 0.25:
		warnings.append("Oksigen sekarat")

	if current_speed <= base_speed * 0.35:
		warnings.append("Kecepatan turun drastis")

	if warnings.is_empty():
		warning_text = "Aman"
	else:
		warning_text = "WARNING: " + " | ".join(warnings)


func _update_ui() -> void:
	if pressure_label:
		pressure_label.text = "[b]Pressure:[/b] " + str(snapped(current_pressure, 0.01)) + " Pa"

	if depth_label:
		depth_label.text = "[b]Depth:[/b] " + str(snapped(current_depth, 0.01)) + " m"

	if stage_label:
		stage_label.text = "[b]Stage:[/b] " + str(current_stage) + " [i](Safe max: " + str(_get_max_safe_stage_from_pressure()) + ")[/i]"

	if coin_label:
		coin_label.text = "[b]Coins:[/b] " + str(GameData.coins)

	if collection_label:
		collection_label.text = "[b]Collection:[/b] " + str(GameData.get_collected_count()) + "/" + str(GameData.fish_database.size()) + " (" + str(snapped(GameData.get_collection_percent(), 0.01)) + "%)"

	if oxygen_label:
		var refill_status: String = ""
		if _is_on_surface_for_refill() and current_oxygen < max_oxygen and not is_dead:
			refill_status = " [i](Refill " + str(snapped(surface_refill_timer, 0.01)) + "/" + str(refill_wait_time) + "s)[/i]"

		oxygen_label.text = (
			"[b]Oxygen:[/b] "
			+ str(snapped(current_oxygen, 0.01))
			+ "/"
			+ str(snapped(max_oxygen, 0.01))
			+ " [i](Emergency " + str(snapped(_get_current_danger_countdown_duration(), 0.01)) + "s)[/i]"
			+ refill_status
		)

	if oxygen_upgrade_label:
		var next_cost_o2: int = _get_oxygen_upgrade_cost()
		var cost_text_o2: String = "MAX" if next_cost_o2 < 0 else str(next_cost_o2)
		oxygen_upgrade_label.text = "[b]Oxygen Tank Lv:[/b] " + str(oxygen_tank_level) + "/" + str(MAX_UPGRADE_LEVEL) + " [i](Cost " + cost_text_o2 + ")[/i]"

	if pressure_upgrade_label:
		var next_cost_pressure: int = _get_pressure_upgrade_cost()
		var cost_text_pressure: String = "MAX" if next_cost_pressure < 0 else str(next_cost_pressure)
		pressure_upgrade_label.text = "[b]Pressure Hull Lv:[/b] " + str(pressure_hull_level) + "/" + str(MAX_UPGRADE_LEVEL) + " [i](Cost " + cost_text_pressure + ")[/i]"

	if propeller_upgrade_label:
		var next_cost_prop: int = _get_propeller_upgrade_cost()
		var cost_text_prop: String = "MAX" if next_cost_prop < 0 else str(next_cost_prop)
		propeller_upgrade_label.text = "[b]Propeller Lv:[/b] " + str(propeller_level) + "/" + str(MAX_UPGRADE_LEVEL) + " [i](Speed " + str(snapped(current_speed, 0.01)) + " | Cost " + cost_text_prop + ")[/i]"

	if upgrade_hint_label:
		upgrade_hint_label.text = "[b]Upgrade Hint:[/b] 1=Oxygen  2=Pressure  3=Propeller | " + upgrade_info_text

	if warning_label:
		warning_label.text = "[b]Status:[/b] " + warning_text

	if how_to_play_label:
		how_to_play_label.text = "[b]Cara Main:[/b] Panah/WASD = Gerak | E = Scan | 1 = Upgrade Oxygen | 2 = Upgrade Pressure | 3 = Upgrade Propeller | Naik ke permukaan untuk isi ulang oxygen | Level Oxygen menambah waktu darurat | Cari pohon di dasar laut dan scan pohon itu untuk menang"


func _handle_scan_input() -> void:
	if is_dead:
		return

	if Input.is_action_just_pressed("scan"):
		_scan_nearest_target()


func _scan_nearest_target() -> void:
	var scannables: Array = []
	scannables.append_array(get_tree().get_nodes_in_group("fish"))
	scannables.append_array(get_tree().get_nodes_in_group("goal_tree"))

	var nearest_target: Node2D = null
	var nearest_distance: float = INF

	for target: Node in scannables:
		if not is_instance_valid(target):
			continue

		if target is Node2D:
			var target_node: Node2D = target as Node2D
			var distance: float = global_position.distance_to(target_node.global_position)

			if distance <= scan_radius and distance < nearest_distance:
				nearest_distance = distance
				nearest_target = target_node

	if nearest_target == null:
		print("Tidak ada target scan dalam radius.")
		return

	if nearest_target.is_in_group("goal_tree"):
		_win_game()
		return

	if nearest_target.is_in_group("fish"):
		var reward: int = nearest_target.scan_fish()
		print("Scan berhasil, reward: ", reward)
		print("Total coins: ", GameData.coins)


func _print_ocean_state_if_changed() -> void:
	if (
		is_equal_approx(current_depth, _last_printed_depth)
		and is_equal_approx(current_pressure, _last_printed_pressure)
		and is_equal_approx(current_pressure_normalized, _last_printed_pressure_normalized)
		and current_stage == _last_printed_stage
	):
		return

	print("Depth: ", snapped(current_depth, 0.01), " m")
	print("Pressure raw: ", snapped(current_pressure, 0.01), " Pa")
	print("Pressure normalized: ", snapped(current_pressure_normalized, 0.001))
	print("Depth percent: ", snapped(current_depth_percent * 100.0, 0.01), "%")
	print("Stage: ", current_stage)
	print("Safe stage by pressure: ", _get_max_safe_stage_from_pressure())
	print("Oxygen: ", snapped(current_oxygen, 0.01), "/", snapped(max_oxygen, 0.01))
	print("Speed: ", snapped(current_speed, 0.01))
	print("Emergency: ", is_in_emergency, " timer: ", snapped(emergency_timer, 0.01))
	print("Visual tier: ", _get_visual_tier())
	print("Warning: ", warning_text)
	print("------")

	_last_printed_depth = current_depth
	_last_printed_pressure = current_pressure
	_last_printed_pressure_normalized = current_pressure_normalized
	_last_printed_stage = current_stage


func _is_above_surface() -> bool:
	return global_position.y < surface_level_y


func get_depth() -> float:
	return clamp(global_position.y - surface_level_y, 0.0, sea_floor_depth)


func get_pressure() -> float:
	return SURFACE_PRESSURE + SEA_WATER_DENSITY * WATER_GRAVITY * get_depth()


func get_max_pressure() -> float:
	return SURFACE_PRESSURE + SEA_WATER_DENSITY * WATER_GRAVITY * sea_floor_depth


func get_pressure_normalized() -> float:
	var min_pressure: float = SURFACE_PRESSURE
	var max_pressure: float = get_max_pressure()

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


func get_stage_from_depth(depth: float) -> int:
	if depth < 800.0:
		return 1
	elif depth < 1600.0:
		return 2
	elif depth < 2400.0:
		return 3
	elif depth < 3200.0:
		return 4
	elif depth < 4200.0:
		return 5
	return 6
