## Helper for resolving encounter IDs to authored encounter data and presentation scenes.
class_name DungeonEncounterResolver
extends RefCounted

static func encounter_for_id(encounter_pool: Resource, encounter_id: StringName) -> Resource:
	if encounter_pool == null or String(encounter_id).is_empty():
		return null
	if not encounter_pool.has_method("get_encounter"):
		return null

	return encounter_pool.call("get_encounter", encounter_id) as Resource

static func scene_for_encounter(encounter_pool: Resource, encounter_data: Resource) -> PackedScene:
	if encounter_pool != null and encounter_pool.has_method("scene_for_encounter"):
		return encounter_pool.call("scene_for_encounter", encounter_data) as PackedScene

	if encounter_data == null:
		return null

	var scene_override := encounter_data.get("scene_override") as PackedScene
	return scene_override

static func choice_for_index(encounter_data: Resource, choice_index: int) -> Dictionary:
	if encounter_data == null or choice_index < 0:
		return {}

	var raw_choices: Variant = encounter_data.get("choices")
	if not (raw_choices is Array):
		return {}
	var choices: Array = raw_choices
	if choice_index >= choices.size():
		return {}
	var choice: Variant = choices[choice_index]
	if choice is Dictionary:
		return choice

	return {}
