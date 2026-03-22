extends Node

var coins: int = 0

var fish_database: Array = [
	{"id":"fish_01","name":"Ikan Stage 1A","stage":1,"base_value":10,"rare":false,"collected":false,"sprite_path":"res://sprite/ikan_kecil1.png"},
	{"id":"fish_02","name":"Ikan Stage 1B","stage":1,"base_value":12,"rare":true,"collected":false,"sprite_path":"res://sprite/ikan_kecil2.png"},

	{"id":"fish_03","name":"Ikan Stage 2A","stage":2,"base_value":18,"rare":false,"collected":false,"sprite_path":"res://sprite/ikan_kecil3.png"},
	{"id":"fish_04","name":"Ikan Stage 2B","stage":2,"base_value":20,"rare":true,"collected":false,"sprite_path":"res://sprite/ikan_kecil4.png"},

	{"id":"fish_05","name":"Ikan Stage 3A","stage":3,"base_value":28,"rare":false,"collected":false,"sprite_path":"res://sprite/ikan_sedang1.png"},
	{"id":"fish_06","name":"Ikan Stage 3B","stage":3,"base_value":30,"rare":true,"collected":false,"sprite_path":"res://sprite/ikan_sedang2.png"},

	{"id":"fish_07","name":"Ikan Stage 4A","stage":4,"base_value":44,"rare":true,"collected":false,"sprite_path":"res://sprite/ikan_besar1.png"},

	{"id":"fish_08","name":"Ikan Stage 5A","stage":5,"base_value":55,"rare":false,"collected":false,"sprite_path":"res://sprite/ikan_besar2.png"},
	{"id":"fish_09","name":"Ikan Stage 6A","stage":6,"base_value":75,"rare":true,"collected":false,"sprite_path":"res://sprite/ikan_besar3.png"}
]


func get_fish_by_stage(stage: int) -> Array:
	var result: Array = []

	for fish in fish_database:
		if fish["stage"] == stage:
			result.append(fish)

	return result


func get_fish_data_by_id(fish_id: String) -> Dictionary:
	for fish in fish_database:
		if fish["id"] == fish_id:
			return fish
	return {}


func get_fish_sell_value(fish_data: Dictionary) -> int:
	var value: float = fish_data["base_value"]

	if fish_data["rare"] == true:
		value *= 1.25

	return int(round(value))


func collect_fish(fish_id: String) -> int:
	for fish in fish_database:
		if fish["id"] == fish_id:
			if fish["collected"]:
				return 0

			fish["collected"] = true

			var reward: int = get_fish_sell_value(fish)
			coins += reward
			return reward

	return 0


func is_fish_collected(fish_id: String) -> bool:
	for fish in fish_database:
		if fish["id"] == fish_id:
			return fish["collected"]
	return false


func get_collection_percent() -> float:
	if fish_database.is_empty():
		return 0.0

	var collected_count: int = 0

	for fish in fish_database:
		if fish["collected"]:
			collected_count += 1

	return float(collected_count) / float(fish_database.size()) * 100.0
