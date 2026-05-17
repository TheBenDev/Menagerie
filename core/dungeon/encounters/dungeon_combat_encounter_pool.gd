## Resource registry that scans, filters, and picks seeded combat encounter profiles for Fight/Boss nodes.
class_name DungeonCombatEncounterPool
extends Resource

const DungeonEncounterPoolHelperScript := preload("res://core/dungeon/encounters/dungeon_encounter_pool_helper.gd")

@export var scan_roots: Array[String] = ["res://core/dungeon/encounters/combat"]

var _encounter_cache: Array[Resource] = []
var _encounters_by_id: Dictionary = {}
var _path_by_id: Dictionary = {}
var _is_loaded: bool = false

func get_encounter(encounter_id: StringName) -> Resource:
	_ensure_loaded()
	return _encounters_by_id.get(String(encounter_id), null) as Resource

func profile_path_for_id(encounter_id: StringName) -> String:
	_ensure_loaded()
	return str(_path_by_id.get(String(encounter_id), ""))

func available_for_floor(floor_layer: int) -> Array[Resource]:
	_ensure_loaded()
	return DungeonEncounterPoolHelperScript.available_for_floor(_encounter_cache, floor_layer)

func pick_for_floor(floor_layer: int) -> Resource:
	var available := available_for_floor(floor_layer)
	return DungeonEncounterPoolHelperScript.pick_weighted(available)

func reload() -> void:
	_encounter_cache.clear()
	_encounters_by_id.clear()
	_path_by_id.clear()
	_is_loaded = true

	var paths := _encounter_paths()
	for encounter_path in paths:
		var encounter_data := load(encounter_path) as Resource
		if encounter_data == null:
			continue

		var encounter_id := String(encounter_data.get("id"))
		if encounter_id.is_empty():
			push_warning("Dungeon combat encounter at %s has no id." % encounter_path)
			continue
		if _encounters_by_id.has(encounter_id):
			push_warning("Duplicate dungeon combat encounter id %s at %s. Keeping the first loaded resource." % [encounter_id, encounter_path])
			continue

		_encounter_cache.append(encounter_data)
		_encounters_by_id[encounter_id] = encounter_data
		_path_by_id[encounter_id] = encounter_path

func _ensure_loaded() -> void:
	if not _is_loaded:
		reload()

func _encounter_paths() -> Array[String]:
	return DungeonEncounterPoolHelperScript.encounter_paths(scan_roots, "Dungeon combat encounter")
