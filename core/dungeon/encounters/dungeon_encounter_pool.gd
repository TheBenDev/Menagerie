## Resource registry that scans folders, filters encounters by floor layer, and chooses weighted events.
class_name DungeonEncounterPool
extends Resource

const DungeonEncounterPoolHelperScript := preload("res://core/dungeon/encounters/dungeon_encounter_pool_helper.gd")

@export var scan_roots: Array[String] = ["res://core/dungeon/encounters/events"]
@export var default_scene: PackedScene = null

var _encounter_cache: Array[Resource] = []
var _encounters_by_id: Dictionary = {}
var _is_loaded: bool = false

func get_encounter(encounter_id: StringName) -> Resource:
	_ensure_loaded()
	return _encounters_by_id.get(String(encounter_id), null) as Resource

func available_for_floor(floor_layer: int) -> Array[Resource]:
	_ensure_loaded()
	return DungeonEncounterPoolHelperScript.available_for_floor(_encounter_cache, floor_layer)

func pick_for_floor(floor_layer: int) -> Resource:
	var available := available_for_floor(floor_layer)
	return DungeonEncounterPoolHelperScript.pick_weighted(available)

func scene_for_encounter(encounter_data: Resource) -> PackedScene:
	if encounter_data == null:
		return default_scene

	var scene_override := encounter_data.get("scene_override") as PackedScene
	if scene_override != null:
		return scene_override

	return default_scene

func reload() -> void:
	_encounter_cache.clear()
	_encounters_by_id.clear()
	_is_loaded = true

	var paths := _encounter_paths()
	for encounter_path in paths:
		var encounter_data := load(encounter_path) as Resource
		if encounter_data == null:
			continue

		var encounter_id := String(encounter_data.get("id"))
		if encounter_id.is_empty():
			push_warning("Dungeon encounter at %s has no id." % encounter_path)
			continue
		if _encounters_by_id.has(encounter_id):
			push_warning("Duplicate dungeon encounter id %s at %s. Keeping the first loaded resource." % [encounter_id, encounter_path])
			continue

		_encounter_cache.append(encounter_data)
		_encounters_by_id[encounter_id] = encounter_data

func _ensure_loaded() -> void:
	if not _is_loaded:
		reload()

func _encounter_paths() -> Array[String]:
	return DungeonEncounterPoolHelperScript.encounter_paths(scan_roots, "Dungeon encounter")
