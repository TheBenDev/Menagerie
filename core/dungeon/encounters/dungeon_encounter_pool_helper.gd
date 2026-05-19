## Shared scan, filter, and weighted-pick helpers for authored dungeon encounter pools.
class_name DungeonEncounterPoolHelper
extends RefCounted

static func available_for_floor(encounters: Array[Resource], floor_layer: int) -> Array[Resource]:
	var available: Array[Resource] = []
	for encounter in encounters:
		var encounter_data := encounter as Resource
		if encounter_data == null or float(encounter_data.get("weight")) <= 0.0:
			continue
		if is_valid_for_floor(encounter_data, floor_layer):
			available.append(encounter_data)

	return available

static func pick_weighted(encounters: Array[Resource], rng: RandomNumberGenerator) -> Resource:
	if encounters.is_empty() or rng == null:
		return null

	var total_weight := 0.0
	for encounter in encounters:
		total_weight += max(float(encounter.get("weight")), 0.0)
	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	var running_weight := 0.0
	for encounter in encounters:
		running_weight += max(float(encounter.get("weight")), 0.0)
		if roll <= running_weight:
			return encounter

	return encounters[encounters.size() - 1]

static func is_valid_for_floor(encounter_data: Resource, floor_layer: int) -> bool:
	var valid_floor_layers: Array = encounter_data.get("valid_floor_layers")
	if valid_floor_layers.is_empty():
		return true

	return valid_floor_layers.has(max(floor_layer, 1))

static func encounter_paths(scan_roots: Array[String], warning_prefix: String) -> Array[String]:
	var paths: Array[String] = []
	for scan_root in scan_roots:
		_collect_encounter_paths(scan_root, paths, warning_prefix)
	paths.sort()
	return paths

static func _collect_encounter_paths(scan_root: String, paths: Array[String], warning_prefix: String) -> void:
	var dir := DirAccess.open(scan_root)
	if dir == null:
		push_warning("%s scan root could not be opened: %s" % [warning_prefix, scan_root])
		return

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while not entry_name.is_empty():
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue

		var entry_path := scan_root.path_join(entry_name)
		if dir.current_is_dir():
			_collect_encounter_paths(entry_path, paths, warning_prefix)
		else:
			var encounter_path := _resource_path_from_export_entry(entry_path)
			if encounter_path.get_extension().to_lower() == "tres" and not paths.has(encounter_path):
				paths.append(encounter_path)

		entry_name = dir.get_next()

static func _resource_path_from_export_entry(entry_path: String) -> String:
	if entry_path.ends_with(".remap"):
		return entry_path.trim_suffix(".remap")

	return entry_path
