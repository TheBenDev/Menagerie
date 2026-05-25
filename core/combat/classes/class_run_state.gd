## Shared run-scoped class state for stances, learned skills, flex slots, passives, upgrades, and pending rewards.
class_name ClassRunState
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

const MAX_STANCE_SKILL_SLOTS := 3
const MAX_FLEX_SLOTS := 3
const DEFAULT_CONSUMABLE_SLOTS := 2

var unlocked_stance_ids: Array[StringName] = []
var active_stance_id: StringName = &""
var unlocked_stance_skill_slots_by_stance: Dictionary = {}
var unlocked_flex_slots: int = 0
var unlocked_consumable_slots: int = DEFAULT_CONSUMABLE_SLOTS
var stance_skill_ids_by_stance: Dictionary = {}
var skillbook_ids: Array[StringName] = []
var passive_ids: Array[StringName] = []
var upgrade_ids: Array[StringName] = []
var visible_flex_skill_ids: Array[StringName] = []
var memory_level: int = 0
var pending_reward_context: Dictionary = {}

func configure_defaults(class_profile: Resource) -> void:
	if class_profile == null:
		push_error("ClassRunState cannot configure defaults without a ClassProfileData.")
		return
	for stance_id in class_profile.call("stance_ids"):
		if not unlocked_stance_skill_slots_by_stance.has(stance_id):
			unlocked_stance_skill_slots_by_stance[stance_id] = 0
		if not stance_skill_ids_by_stance.has(stance_id):
			var stance: Resource = class_profile.call("get_stance", stance_id) as Resource
			var fixed_skill_ids: Array = stance.get("fixed_skill_ids") if stance != null else []
			stance_skill_ids_by_stance[stance_id] = fixed_skill_ids.duplicate() if stance != null else []
	unlocked_consumable_slots = max(unlocked_consumable_slots, DEFAULT_CONSUMABLE_SLOTS)
	_resize_flex_slots()

func has_pending_reward() -> bool:
	return not pending_reward_context.is_empty()

func clear_pending_reward() -> void:
	pending_reward_context.clear()

func unlock_stance(stance_id: StringName, class_profile: Resource, make_active: bool = false) -> void:
	if stance_id == &"":
		push_error("Cannot unlock an empty class stance id.")
		return
	if class_profile == null or class_profile.call("get_stance", stance_id) == null:
		push_error("Cannot unlock unknown class stance: %s." % stance_id)
		return
	if not unlocked_stance_ids.has(stance_id):
		unlocked_stance_ids.append(stance_id)
	if int(unlocked_stance_skill_slots_by_stance.get(stance_id, 0)) <= 0:
		unlocked_stance_skill_slots_by_stance[stance_id] = 1
	if make_active or active_stance_id == &"":
		active_stance_id = stance_id

func unlock_flex_slots(count: int) -> void:
	if count <= 0:
		push_error("Class flex slot unlock count must be positive.")
		return
	unlocked_flex_slots = clamp(unlocked_flex_slots + count, 0, MAX_FLEX_SLOTS)
	_resize_flex_slots()

func learn_skill(skill_id: StringName, class_profile: Resource) -> void:
	if skill_id == &"":
		push_error("Cannot learn an empty class skill id.")
		return
	if class_profile == null or class_profile.call("get_skill", skill_id) == null:
		push_error("Cannot learn unknown class skill: %s." % skill_id)
		return
	if not skillbook_ids.has(skill_id):
		skillbook_ids.append(skill_id)

func add_passive(passive_id: StringName, class_profile: Resource) -> void:
	if passive_id == &"":
		push_error("Cannot add an empty class passive id.")
		return
	if class_profile == null or class_profile.call("get_passive", passive_id) == null:
		push_error("Cannot add unknown class passive: %s." % passive_id)
		return
	if not passive_ids.has(passive_id):
		passive_ids.append(passive_id)

func add_upgrade(upgrade_id: StringName, class_profile: Resource) -> void:
	if upgrade_id == &"":
		push_error("Cannot add an empty class upgrade id.")
		return
	if class_profile == null or class_profile.call("get_upgrade", upgrade_id) == null:
		push_error("Cannot add unknown class upgrade: %s." % upgrade_id)
		return
	if not upgrade_ids.has(upgrade_id):
		upgrade_ids.append(upgrade_id)

func reroll_flex_slots(class_profile: Resource) -> void:
	if unlocked_flex_slots <= 0:
		visible_flex_skill_ids.clear()
		return
	_resize_flex_slots()
	var candidates: Array[StringName] = valid_flex_skill_ids(class_profile)
	if candidates.size() < unlocked_flex_slots:
		push_error("Class has %s unlocked flex slots but only %s valid flex skills." % [unlocked_flex_slots, candidates.size()])
		return
	var selected: Array[StringName] = []
	for index in range(unlocked_flex_slots):
		var remaining: Array[StringName] = []
		for candidate in candidates:
			if not selected.has(candidate):
				remaining.append(candidate)
		if remaining.is_empty():
			push_error("Class flex reroll ran out of unique skill candidates.")
			return
		var picked: StringName = remaining.pick_random()
		selected.append(picked)
		visible_flex_skill_ids[index] = picked

func replace_flex_slot(slot_index: int, class_profile: Resource) -> void:
	if slot_index < 0 or slot_index >= unlocked_flex_slots:
		push_error("Cannot replace invalid class flex slot index %s." % slot_index)
		return
	var candidates: Array[StringName] = valid_flex_skill_ids(class_profile)
	var active_ids: Array[StringName] = []
	for index in range(unlocked_flex_slots):
		if index == slot_index:
			continue
		var active_id: StringName = StringName(str(visible_flex_skill_ids[index])) if index < visible_flex_skill_ids.size() else &""
		if active_id != &"":
			active_ids.append(active_id)
	var remaining: Array[StringName] = []
	for candidate in candidates:
		if not active_ids.has(candidate):
			remaining.append(candidate)
	if remaining.is_empty():
		push_error("Class flex slot %s has no replacement candidates." % slot_index)
		return
	visible_flex_skill_ids[slot_index] = remaining.pick_random()

func to_snapshot() -> Dictionary:
	return {
		"unlocked_stance_ids": ValueReaderScript.string_array(unlocked_stance_ids),
		"active_stance_id": String(active_stance_id),
		"unlocked_stance_skill_slots_by_stance": _string_key_int_dictionary(unlocked_stance_skill_slots_by_stance),
		"unlocked_flex_slots": unlocked_flex_slots,
		"unlocked_consumable_slots": unlocked_consumable_slots,
		"stance_skill_ids_by_stance": _string_key_string_array_dictionary(stance_skill_ids_by_stance),
		"skillbook_ids": ValueReaderScript.string_array(skillbook_ids),
		"passive_ids": ValueReaderScript.string_array(passive_ids),
		"upgrade_ids": ValueReaderScript.string_array(upgrade_ids),
		"visible_flex_skill_ids": ValueReaderScript.string_array(visible_flex_skill_ids),
		"memory_level": memory_level,
		"pending_reward_context": pending_reward_context.duplicate(true),
	}

func apply_snapshot(snapshot: Dictionary) -> void:
	unlocked_stance_ids = ValueReaderScript.string_name_array(snapshot.get("unlocked_stance_ids", []))
	active_stance_id = StringName(str(snapshot.get("active_stance_id", "")))
	unlocked_stance_skill_slots_by_stance = _string_name_key_dictionary(snapshot.get("unlocked_stance_skill_slots_by_stance", {}))
	unlocked_flex_slots = int(snapshot.get("unlocked_flex_slots", 0))
	unlocked_consumable_slots = int(snapshot.get("unlocked_consumable_slots", DEFAULT_CONSUMABLE_SLOTS))
	stance_skill_ids_by_stance = _string_name_array_dictionary(snapshot.get("stance_skill_ids_by_stance", {}))
	skillbook_ids = ValueReaderScript.string_name_array(snapshot.get("skillbook_ids", []))
	passive_ids = ValueReaderScript.string_name_array(snapshot.get("passive_ids", []))
	upgrade_ids = ValueReaderScript.string_name_array(snapshot.get("upgrade_ids", []))
	visible_flex_skill_ids = ValueReaderScript.string_name_array(snapshot.get("visible_flex_skill_ids", []))
	memory_level = int(snapshot.get("memory_level", 0))
	var pending_value: Variant = snapshot.get("pending_reward_context", {})
	pending_reward_context = pending_value.duplicate(true) if pending_value is Dictionary else {}
	_resize_flex_slots()

func valid_flex_skill_ids(class_profile: Resource) -> Array[StringName]:
	var ids: Array[StringName] = []
	if class_profile == null:
		return ids
	for skill_id in skillbook_ids:
		var skill: Resource = class_profile.call("get_skill", skill_id) as Resource
		if skill == null or not bool(skill.get("valid_as_flex_skill")):
			continue
		var skill_stance_id: StringName = StringName(str(skill.get("stance_id")))
		if skill_stance_id != &"" and skill_stance_id != active_stance_id:
			continue
		if not ids.has(skill_id):
			ids.append(skill_id)
	return ids

func _resize_flex_slots() -> void:
	unlocked_flex_slots = clamp(unlocked_flex_slots, 0, MAX_FLEX_SLOTS)
	while visible_flex_skill_ids.size() < unlocked_flex_slots:
		visible_flex_skill_ids.append(&"")
	while visible_flex_skill_ids.size() > unlocked_flex_slots:
		visible_flex_skill_ids.pop_back()

func _string_key_int_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[String(key)] = int(source[key])
	return result

func _string_key_string_array_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[String(key)] = ValueReaderScript.string_array(source[key])
	return result

func _string_name_key_dictionary(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		var dictionary: Dictionary = source
		for key in dictionary.keys():
			result[StringName(str(key))] = int(dictionary[key])
	return result

func _string_name_array_dictionary(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		var dictionary: Dictionary = source
		for key in dictionary.keys():
			result[StringName(str(key))] = ValueReaderScript.string_name_array(dictionary[key])
	return result
