## Resource defining one seeded Fight/Boss combat encounter and its enemy slots.
class_name DungeonCombatEncounterData
extends Resource

const SLOT_COMBATANT_PROFILE_PATH := "combatant_profile_path"
const SLOT_POSITION_ID := "position_id"
const SLOT_MODIFIER_DATA := "modifier_data"

@export var id: StringName = &""
@export var display_name: String = "Combat Encounter"
@export_multiline var description: String = ""
@export var valid_floor_layers: Array[int] = []
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var enemy_slots: Array[Dictionary] = []

func is_valid_for_floor(floor_layer: int) -> bool:
	if valid_floor_layers.is_empty():
		return true

	return valid_floor_layers.has(max(floor_layer, 1))

## Returns the first enemy profile path for the current one-enemy battle scene bridge.
func primary_enemy_profile_path() -> String:
	for slot in enemy_slots:
		var slot_data: Dictionary = slot
		var profile_path := str(slot_data.get(SLOT_COMBATANT_PROFILE_PATH, "")).strip_edges()
		if not profile_path.is_empty():
			return profile_path

	return ""

func enemy_profile_paths() -> Array[String]:
	var profile_paths: Array[String] = []
	for slot in enemy_slots:
		var slot_data: Dictionary = slot
		var profile_path := str(slot_data.get(SLOT_COMBATANT_PROFILE_PATH, "")).strip_edges()
		if profile_path.is_empty() or profile_paths.has(profile_path):
			continue
		profile_paths.append(profile_path)

	return profile_paths
