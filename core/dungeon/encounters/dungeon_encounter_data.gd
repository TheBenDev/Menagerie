## Resource defining one seeded dungeon encounter, its optional custom scene, and inline choices.
class_name DungeonEncounterData
extends Resource

const DungeonEncounterPoolHelperScript := preload("res://core/dungeon/encounters/dungeon_encounter_pool_helper.gd")

@export var id: StringName = &""
@export var display_name: String = "Encounter"
@export_multiline var description: String = ""
@export var valid_floor_layers: Array[int] = []
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var scene_override: PackedScene = null
@export var choices: Array[Dictionary] = []

func is_valid_for_floor(floor_layer: int) -> bool:
	return DungeonEncounterPoolHelperScript.is_valid_for_floor(self, floor_layer)

func scene_or_default(default_scene: PackedScene) -> PackedScene:
	if scene_override != null:
		return scene_override

	return default_scene
