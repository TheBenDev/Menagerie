## Editable tuning profile for deterministic dungeon floor generation.
class_name DungeonFloorGenerationConfig
extends Resource

@export var base_grid_width: int = 20
@export var base_grid_height: int = 20
@export var grid_width_per_layer: int = 5
@export var grid_height_per_layer: int = 5
@export var grid_width_per_difficulty: int = 3
@export var grid_height_per_difficulty: int = 3
@export var max_grid_width: int = 100
@export var max_grid_height: int = 100

@export var base_fight_count: int = 2
@export var fight_count_per_layer: int = 1
@export var fight_count_per_difficulty: int = 1
@export var min_fight_count: int = 1
@export var max_fight_count: int = 8
@export var enemy_level_ranges_by_floor: Dictionary = {
	1: Vector2i(0, 5),
}

@export var base_encounter_count: int = 1
@export var encounter_count_per_layer: int = 1
@export var encounter_count_per_difficulty: int = 1
@export var min_encounter_count: int = 1
@export var max_encounter_count: int = 6

@export_range(0.0, 1.0, 0.01) var base_branch_chance: float = 0.10
@export_range(0.0, 1.0, 0.01) var branch_chance_per_layer: float = 0.05
@export_range(0.0, 1.0, 0.01) var branch_chance_per_difficulty: float = 0.15
@export_range(0.0, 1.0, 0.01) var base_extra_connection_chance: float = 0.04
@export_range(0.0, 1.0, 0.01) var extra_connection_chance_per_layer: float = 0.04
@export_range(0.0, 1.0, 0.01) var extra_connection_chance_per_difficulty: float = 0.12
@export_range(0.0, 1.0, 0.01) var base_path_noise: float = 0.08
@export_range(0.0, 1.0, 0.01) var path_noise_per_layer: float = 0.03
@export_range(0.0, 1.0, 0.01) var path_noise_per_difficulty: float = 0.10

@export var room_padding: int = 1
@export var max_room_placement_attempts: int = 200
@export var max_generation_retries: int = 16

func enemy_level_range_for_floor(floor_layer: int) -> Vector2i:
	var resolved_floor: int = max(floor_layer, 1)
	if enemy_level_ranges_by_floor.has(resolved_floor):
		return _normalized_level_range(enemy_level_ranges_by_floor[resolved_floor])

	var closest_floor: int = -1
	for raw_floor in enemy_level_ranges_by_floor.keys():
		var floor_value: int = int(raw_floor)
		if floor_value <= resolved_floor and floor_value > closest_floor:
			closest_floor = floor_value

	if closest_floor >= 0:
		return _normalized_level_range(enemy_level_ranges_by_floor[closest_floor])

	return Vector2i(0, 5)

func _normalized_level_range(raw_range: Variant) -> Vector2i:
	if raw_range is Vector2i:
		var range_value := raw_range as Vector2i
		return Vector2i(mini(range_value.x, range_value.y), maxi(range_value.x, range_value.y))
	if raw_range is Vector2:
		var range_value := raw_range as Vector2
		return Vector2i(mini(int(range_value.x), int(range_value.y)), maxi(int(range_value.x), int(range_value.y)))
	if raw_range is Array and raw_range.size() >= 2:
		return Vector2i(mini(int(raw_range[0]), int(raw_range[1])), maxi(int(raw_range[0]), int(raw_range[1])))

	return Vector2i(0, 5)
