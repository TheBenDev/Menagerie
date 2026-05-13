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
