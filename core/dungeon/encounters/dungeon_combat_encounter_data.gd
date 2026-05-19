## Resource defining one seeded Fight/Boss combat encounter and its enemy slots.
class_name DungeonCombatEncounterData
extends Resource

const DungeonEncounterPoolHelperScript := preload("res://core/dungeon/encounters/dungeon_encounter_pool_helper.gd")

const SLOT_COMBATANT_PROFILE_PATH := "combatant_profile_path"
const SLOT_POSITION_ID := "position_id"
const SLOT_MODIFIER_DATA := "modifier_data"

@export var id: StringName = &""
@export var display_name: String = "Combat Encounter"
@export_multiline var description: String = ""
@export var valid_floor_layers: Array[int] = []
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(1, 8, 1) var min_enemy_count: int = 1:
	set(value):
		min_enemy_count = value
		if min_enemy_count > max_enemy_count:
			max_enemy_count = min_enemy_count
@export_range(1, 8, 1) var max_enemy_count: int = 1:
	set(value):
		max_enemy_count = value
		if max_enemy_count < min_enemy_count:
			min_enemy_count = max_enemy_count
@export var enemy_slots: Array[Dictionary] = []

func _ready() -> void:
	if min_enemy_count > max_enemy_count:
		push_warning("DungeonCombatEncounterData %s has min_enemy_count > max_enemy_count, swapping values." % id)
		var temp := min_enemy_count
		min_enemy_count = max_enemy_count
		max_enemy_count = temp

func is_valid_for_floor(floor_layer: int) -> bool:
	return DungeonEncounterPoolHelperScript.is_valid_for_floor(self, floor_layer)

func enemy_profile_paths() -> Array[String]:
	var profile_paths: Array[String] = []
	for slot in enemy_slots:
		var slot_data: Dictionary = slot
		var profile_path := str(slot_data.get(SLOT_COMBATANT_PROFILE_PATH, "")).strip_edges()
		if profile_path.is_empty() or profile_paths.has(profile_path):
			continue
		profile_paths.append(profile_path)

	return profile_paths
