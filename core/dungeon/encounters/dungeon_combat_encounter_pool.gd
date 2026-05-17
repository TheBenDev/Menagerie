## Resource registry that scans, filters, and picks seeded combat encounter profiles for Fight/Boss nodes.
class_name DungeonCombatEncounterPool
extends Resource

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
	var available: Array[Resource] = []
	for encounter in _encounter_cache:
		var encounter_data := encounter as Resource
		if encounter_data == null or float(encounter_data.get("weight")) <= 0.0:
			continue
		if _is_valid_for_floor(encounter_data, floor_layer):
			available.append(encounter_data)

	return available

func pick_for_floor(floor_layer: int) -> Resource:
	var available := available_for_floor(floor_layer)
	if available.is_empty():
		return null

	var total_weight := 0.0
	for encounter in available:
		total_weight += max(float(encounter.get("weight")), 0.0)
	if total_weight <= 0.0:
		return null

	var roll := randf() * total_weight
	var running_weight := 0.0
	for encounter in available:
		running_weight += max(float(encounter.get("weight")), 0.0)
		if roll <= running_weight:
			return encounter

	return available[available.size() - 1]

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

func _is_valid_for_floor(encounter_data: Resource, floor_layer: int) -> bool:
	var valid_floor_layers: Array = encounter_data.get("valid_floor_layers")
	if valid_floor_layers.is_empty():
		return true

	return valid_floor_layers.has(max(floor_layer, 1))

func _ensure_loaded() -> void:
	if _is_loaded:
		return

	reload()

func _encounter_paths() -> Array[String]:
	var paths: Array[String] = []
	for scan_root in scan_roots:
		_collect_encounter_paths(scan_root, paths)
	paths.sort()
	return paths

func _collect_encounter_paths(scan_root: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(scan_root)
	if dir == null:
		push_warning("Dungeon combat encounter scan root could not be opened: %s" % scan_root)
		return

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while not entry_name.is_empty():
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue

		var entry_path := scan_root.path_join(entry_name)
		if dir.current_is_dir():
			_collect_encounter_paths(entry_path, paths)
		elif entry_name.get_extension().to_lower() == "tres":
			paths.append(entry_path)

		entry_name = dir.get_next()
