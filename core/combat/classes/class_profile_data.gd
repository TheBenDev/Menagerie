## Shared class profile that discovers class actions, resources, stances, passives, and upgrades from class-owned folders.
class_name ClassProfileData
extends Resource

const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const ClassRarityScript := preload("res://core/combat/classes/class_rarity.gd")
const ClassResourceDataScript := preload("res://core/combat/classes/class_resource_data.gd")
const ClassStanceDataScript := preload("res://core/combat/classes/class_stance_data.gd")
const ClassPassiveDataScript := preload("res://core/combat/classes/class_passive_data.gd")
const ClassUpgradeDataScript := preload("res://core/combat/classes/class_upgrade_data.gd")

@export var class_id: StringName = &""
@export var class_root: String = ""
@export var primary_resource_id: StringName = &""
@export var core_strike_action_id: StringName = &""
@export var core_guard_action_id: StringName = &""
@export var stance_order: Array[StringName] = []
@export var memory_milestone_costs: Array[int] = [10, 15, 20, 25, 30]
@export var milestone_rarity_weights: Array[Dictionary] = [
	{"rarity": &"common", "weight": 60.0},
	{"rarity": &"uncommon", "weight": 30.0},
	{"rarity": &"rare", "weight": 10.0},
]

var _actions: Array[PlayerActionData] = []
var _class_resources: Array[Resource] = []
var _stances: Array[Resource] = []
var _passives: Array[Resource] = []
var _upgrades: Array[Resource] = []
var _actions_by_id: Dictionary = {}
var _skills_by_id: Dictionary = {}
var _class_resources_by_id: Dictionary = {}
var _stances_by_id: Dictionary = {}
var _passives_by_id: Dictionary = {}
var _upgrades_by_id: Dictionary = {}
var _switch_actions_by_stance_id: Dictionary = {}
var _is_loaded: bool = false

func reload() -> void:
	_actions.clear()
	_class_resources.clear()
	_stances.clear()
	_passives.clear()
	_upgrades.clear()
	_actions_by_id.clear()
	_skills_by_id.clear()
	_class_resources_by_id.clear()
	_stances_by_id.clear()
	_passives_by_id.clear()
	_upgrades_by_id.clear()
	_switch_actions_by_stance_id.clear()
	_is_loaded = true

	_load_actions()
	_load_resources("resources", ClassResourceDataScript, _class_resources, _class_resources_by_id)
	_load_resources("stances", ClassStanceDataScript, _stances, _stances_by_id)
	_load_resources("passives", ClassPassiveDataScript, _passives, _passives_by_id)
	_load_resources("upgrades", ClassUpgradeDataScript, _upgrades, _upgrades_by_id)

func validate() -> String:
	_ensure_loaded()
	if class_id == &"":
		return "ClassProfileData is missing class_id."
	if class_root.strip_edges().is_empty():
		return "ClassProfileData %s is missing class_root." % class_id
	if primary_resource_id != &"" and get_class_resource(primary_resource_id) == null:
		return "ClassProfileData %s is missing primary class resource %s." % [class_id, primary_resource_id]
	if get_action(core_strike_action_id) == null:
		return "ClassProfileData %s is missing core_strike_action_id %s." % [class_id, core_strike_action_id]
	if get_action(core_guard_action_id) == null:
		return "ClassProfileData %s is missing core_guard_action_id %s." % [class_id, core_guard_action_id]
	for class_resource in _class_resources:
		var resource_error: String = str(class_resource.call("validate")) if class_resource != null and class_resource.has_method("validate") else ""
		if not resource_error.is_empty():
			return resource_error
	if _stances.is_empty():
		return "ClassProfileData %s has no stances." % class_id
	for stance in _ordered_stances():
		var stance_error: String = str(stance.call("validate")) if stance != null and stance.has_method("validate") else ""
		if not stance_error.is_empty():
			return stance_error
		if get_action(StringName(str(stance.get("strike_replacement_action_id")))) == null:
			return "ClassProfileData %s stance %s has missing strike replacement %s." % [
				class_id,
				stance.get("id"),
				stance.get("strike_replacement_action_id"),
			]
		for raw_skill_id in stance.get("fixed_skill_ids"):
			if get_skill(StringName(str(raw_skill_id))) == null:
				return "ClassProfileData %s stance %s references missing fixed skill %s." % [
					class_id,
					stance.get("id"),
					raw_skill_id,
				]
	if memory_milestone_costs.is_empty():
		return "ClassProfileData %s is missing memory_milestone_costs." % class_id
	return ""

func actions() -> Array[PlayerActionData]:
	_ensure_loaded()
	return _actions.duplicate()

func class_resources() -> Array[Resource]:
	_ensure_loaded()
	return _class_resources.duplicate()

func passives() -> Array[Resource]:
	_ensure_loaded()
	return _passives.duplicate()

func upgrades() -> Array[Resource]:
	_ensure_loaded()
	return _upgrades.duplicate()

func stance_ids() -> Array[StringName]:
	_ensure_loaded()
	var ids: Array[StringName] = []
	for stance in _ordered_stances():
		if stance != null:
			ids.append(StringName(str(stance.get("id"))))
	return ids

func get_action(action_id: StringName) -> PlayerActionData:
	_ensure_loaded()
	return _actions_by_id.get(String(action_id), null) as PlayerActionData

func get_skill(skill_id: StringName) -> PlayerActionData:
	_ensure_loaded()
	return _skills_by_id.get(String(skill_id), null) as PlayerActionData

func get_class_resource(resource_id: StringName) -> Resource:
	_ensure_loaded()
	return _class_resources_by_id.get(String(resource_id), null) as Resource

func get_stance(stance_id: StringName) -> Resource:
	_ensure_loaded()
	return _stances_by_id.get(String(stance_id), null) as Resource

func get_passive(passive_id: StringName) -> Resource:
	_ensure_loaded()
	return _passives_by_id.get(String(passive_id), null) as Resource

func get_upgrade(upgrade_id: StringName) -> Resource:
	_ensure_loaded()
	return _upgrades_by_id.get(String(upgrade_id), null) as Resource

func get_stance_switch_action(stance_id: StringName) -> PlayerActionData:
	_ensure_loaded()
	if _switch_actions_by_stance_id.has(String(stance_id)):
		return _switch_actions_by_stance_id[String(stance_id)] as PlayerActionData
	var stance: Resource = get_stance(stance_id)
	if stance == null:
		return null

	var action := PlayerActionData.new()
	action.id = "switch_%s" % String(stance_id)
	action.display_name = str(stance.get("display_name"))
	action.description = str(stance.call("resolved_switch_description")) if stance.has_method("resolved_switch_description") else "Enter %s stance." % action.display_name
	action.effect_data = [{
		"id": &"class.stance.switch",
		"stance_id": stance_id,
	}]
	action.time_cost = max(float(stance.get("switch_time_cost")), 0.01)
	action.target_rule = CombatActionData.TARGET_SELF
	action.appears_on_action_bar = false
	action.hover_keywords = ValueReaderScript.string_name_array(stance.get("hover_keywords"))
	_switch_actions_by_stance_id[String(stance_id)] = action
	return action

func all_actions() -> Array[CombatActionData]:
	_ensure_loaded()
	var collected: Array[CombatActionData] = []
	for action in _actions:
		_append_action(collected, action)
	for stance_id in stance_ids():
		_append_action(collected, get_stance_switch_action(stance_id))
	return collected

func next_memory_cost(memory_level: int) -> int:
	if memory_milestone_costs.is_empty():
		push_error("ClassProfileData %s has no memory milestone costs." % class_id)
		return 0
	var index: int = clamp(memory_level, 0, memory_milestone_costs.size() - 1)
	return max(int(memory_milestone_costs[index]), 1)

func _ensure_loaded() -> void:
	if not _is_loaded:
		reload()

func _load_actions() -> void:
	var action_resources: Array[Resource] = []
	var unused_registry: Dictionary = {}
	_load_resources("actions", null, action_resources, unused_registry)
	for resource in action_resources:
		var action := resource as PlayerActionData
		if action == null:
			continue
		var action_id := action.id.strip_edges()
		if action_id.is_empty():
			push_warning("Class action at %s has no id." % action.resource_path)
			continue
		if _actions_by_id.has(action_id):
			push_warning("Duplicate class action id %s at %s. Keeping the first loaded resource." % [action_id, action.resource_path])
			continue
		_actions.append(action)
		_actions_by_id[action_id] = action
		var skill_id := StringName(str(action.get("class_skill_id")))
		if skill_id != &"":
			if _skills_by_id.has(String(skill_id)):
				push_warning("Duplicate class skill id %s at %s. Keeping the first loaded resource." % [skill_id, action.resource_path])
			else:
				_skills_by_id[String(skill_id)] = action

func _load_resources(folder_name: String, expected_script: Script, target: Array, registry: Dictionary) -> void:
	var folder_path := _folder_path(folder_name)
	var paths: Array[String] = []
	_collect_resource_paths(folder_path, paths)
	paths.sort()
	for class_resource_path in paths:
		var resource := load(class_resource_path) as Resource
		if resource == null:
			continue
		if expected_script != null and resource.get_script() != expected_script:
			continue
		if expected_script == null and not (resource is PlayerActionData):
			continue
		var resource_id := String(resource.get("id"))
		if resource_id.is_empty():
			push_warning("Class resource at %s has no id." % class_resource_path)
			continue
		if registry.has(resource_id):
			push_warning("Duplicate class resource id %s at %s. Keeping the first loaded resource." % [resource_id, class_resource_path])
			continue
		target.append(resource)
		registry[resource_id] = resource

func _collect_resource_paths(folder_path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while not entry_name.is_empty():
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue
		var entry_path := folder_path.path_join(entry_name)
		if dir.current_is_dir():
			_collect_resource_paths(entry_path, paths)
		else:
			var discovered_path := _resource_path_from_export_entry(entry_path)
			if discovered_path.get_extension().to_lower() == "tres" and not paths.has(discovered_path):
				paths.append(discovered_path)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _folder_path(folder_name: String) -> String:
	return class_root.trim_suffix("/").path_join(folder_name)

func _ordered_stances() -> Array[Resource]:
	var ordered: Array[Resource] = []
	for stance_id in stance_order:
		var stance: Resource = _stances_by_id.get(String(stance_id), null) as Resource
		if stance != null and not ordered.has(stance):
			ordered.append(stance)
	for stance in _stances:
		if stance != null and not ordered.has(stance):
			ordered.append(stance)
	return ordered

func _append_action(target_actions: Array[CombatActionData], action: CombatActionData) -> void:
	if action != null and not target_actions.has(action):
		target_actions.append(action)

func _resource_path_from_export_entry(entry_path: String) -> String:
	if entry_path.ends_with(".remap"):
		return entry_path.trim_suffix(".remap")
	return entry_path
