## Shared combat hotbar builder for class stances, core actions, stance skills, flex skills, and consumables.
class_name ClassKitBuilder
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const ActionCostServiceScript := preload("res://core/combat/actions/action_cost_service.gd")
const HotbarSlotSchemaScript := preload("res://core/combat/classes/hotbar_slot_schema.gd")

const SLOT_IDS: Array[StringName] = [
	&"stance_1",
	&"stance_2",
	&"stance_3",
	&"strike",
	&"guard",
	&"ability_1",
	&"ability_2",
	&"ability_3",
	&"ability_4",
	&"ability_5",
	&"ability_6",
	&"consumable_1",
	&"consumable_2",
	&"consumable_3",
	&"consumable_4",
]

static func build_slots(actor: Combatant, class_profile: Resource, run_state: Variant) -> Array[Dictionary]:
	if not _validate_inputs(class_profile, run_state):
		return []
	var slots: Array[Dictionary] = []
	for slot_id in SLOT_IDS:
		slots.append(_slot_entry_unchecked(slot_id, actor, class_profile, run_state))
	return slots

static func slot_entry(slot_id: StringName, actor: Combatant, class_profile: Resource, run_state: Variant) -> Dictionary:
	if not _validate_inputs(class_profile, run_state):
		return _slot_hover(slot_id, &"empty", "?", "Invalid Class Kit", "This combatant does not have a valid class kit.")
	return _slot_entry_unchecked(slot_id, actor, class_profile, run_state)

static func _slot_entry_unchecked(slot_id: StringName, actor: Combatant, class_profile: Resource, run_state: Variant) -> Dictionary:
	if String(slot_id).begins_with("stance_"):
		return _stance_slot(slot_id, actor, class_profile, run_state)
	match slot_id:
		&"strike":
			return _action_slot(slot_id, _strike_action(class_profile, run_state), actor, {"label": "S"})
		&"guard":
			return _action_slot(slot_id, class_profile.call("get_action", class_profile.get("core_guard_action_id")) as PlayerActionData, actor, {"label": "B"})
		&"ability_1", &"ability_2", &"ability_3":
			return _stance_skill_slot(slot_id, actor, class_profile, run_state)
		&"ability_4", &"ability_5", &"ability_6":
			return _flex_skill_slot(slot_id, actor, class_profile, run_state)
		&"consumable_1", &"consumable_2", &"consumable_3", &"consumable_4":
			return _consumable_slot(slot_id, run_state)
		_:
			push_error("Unknown class hotbar slot id: %s." % slot_id)
			return _slot_hover(slot_id, &"empty", "?", "Unknown Slot", "This slot is not part of this class kit.")

static func resolved_action_for_slot(slot_id: StringName, actor: Combatant, class_profile: Resource, run_state: Variant) -> PlayerActionData:
	var entry: Dictionary = slot_entry(slot_id, actor, class_profile, run_state)
	if _slot_kind(entry) != &"action":
		return null
	return entry.get("action", null) as PlayerActionData

static func flex_slot_index(slot_id: StringName) -> int:
	match slot_id:
		&"ability_4":
			return 0
		&"ability_5":
			return 1
		&"ability_6":
			return 2
		_:
			return -1

static func _validate_inputs(class_profile: Resource, run_state: Variant) -> bool:
	if class_profile == null:
		push_error("ClassKitBuilder requires a ClassProfileData.")
		return false
	var profile_error: String = str(class_profile.call("validate")) if class_profile.has_method("validate") else ""
	if not profile_error.is_empty():
		push_error(profile_error)
		return false
	if run_state == null:
		push_error("ClassKitBuilder requires a ClassRunState.")
		return false
	if run_state.has_method("configure_defaults"):
		run_state.configure_defaults(class_profile)
	return true

static func _stance_slot(slot_id: StringName, actor: Combatant, class_profile: Resource, run_state: Variant) -> Dictionary:
	var index: int = int(String(slot_id).get_slice("_", 1)) - 1
	var stance_ids: Array = class_profile.call("stance_ids")
	if index < 0 or index >= stance_ids.size():
		return _slot_hover(slot_id, &"empty", "?", "Missing Stance", "No stance is configured for this slot.")
	var stance: Resource = class_profile.call("get_stance", stance_ids[index]) as Resource
	if stance == null:
		return _slot_hover(slot_id, &"empty", "?", "Missing Stance", "The configured stance resource is missing.")
	var stance_id: StringName = StringName(str(stance.get("id")))
	var stance_label: String = str(stance.call("label_text")) if stance.has_method("label_text") else "?"
	var stance_name: String = str(stance.get("display_name"))
	var stance_keywords: Array[StringName] = _keyword_array(stance.get("hover_keywords"))
	if not run_state.unlocked_stance_ids.has(stance_id):
		return _locked_slot(slot_id, stance_label, "Locked: %s" % stance_name, "Unlock this stance from a class reward.", stance_keywords)
	if run_state.active_stance_id == stance_id:
		return _disabled_slot(slot_id, stance_label, stance_name, "This stance is already active.", stance_keywords, stance)
	return _action_slot(slot_id, class_profile.call("get_stance_switch_action", stance_id) as PlayerActionData, actor, {
		"label": stance_label,
		"stance_id": stance_id,
		"resource": stance,
	})

static func _strike_action(class_profile: Resource, run_state: Variant) -> PlayerActionData:
	if run_state.active_stance_id == &"":
		return class_profile.call("get_action", class_profile.get("core_strike_action_id")) as PlayerActionData
	var stance: Resource = class_profile.call("get_stance", run_state.active_stance_id) as Resource
	if stance == null:
		push_error("Active class stance is unknown: %s." % run_state.active_stance_id)
		return null
	return class_profile.call("get_action", stance.get("strike_replacement_action_id")) as PlayerActionData

static func _stance_skill_slot(slot_id: StringName, actor: Combatant, class_profile: Resource, run_state: Variant) -> Dictionary:
	if run_state.active_stance_id == &"":
		return _disabled_slot(slot_id, "?", "No Active Stance", "Choose a class stance before using stance skills.", [], null)
	var stance: Resource = class_profile.call("get_stance", run_state.active_stance_id) as Resource
	if stance == null:
		return _disabled_slot(slot_id, "?", "Invalid Stance", "The active class stance is missing.", [], null)
	var index: int = int(String(slot_id).get_slice("_", 1)) - 1
	var stance_id: StringName = StringName(str(stance.get("id")))
	var stance_name: String = str(stance.get("display_name"))
	var stance_keywords: Array[StringName] = _keyword_array(stance.get("hover_keywords"))
	var unlocked_slots: int = int(run_state.unlocked_stance_skill_slots_by_stance.get(stance_id, 0))
	if index >= unlocked_slots:
		return _locked_slot(slot_id, "L", "Locked Stance Skill", "Unlock more %s stance skills from class rewards." % stance_name, stance_keywords)
	var fixed_skill_ids: Array = stance.get("fixed_skill_ids")
	var skill_ids: Array = run_state.stance_skill_ids_by_stance.get(stance_id, fixed_skill_ids)
	if index < 0 or index >= skill_ids.size():
		return _disabled_slot(slot_id, "?", "Missing Stance Skill", "%s has no configured skill for this slot." % stance_name, stance_keywords, stance)
	var skill: Resource = class_profile.call("get_skill", StringName(str(skill_ids[index]))) as Resource
	if skill == null:
		return _disabled_slot(slot_id, "?", "Missing Skill", "The configured class skill is missing.", stance_keywords, stance)
	return _action_slot(slot_id, skill as PlayerActionData, actor, {
		"label": _label_for_skill(skill),
		"skill_id": StringName(str(skill.get("class_skill_id"))),
		"resource": skill,
	})

static func _flex_skill_slot(slot_id: StringName, actor: Combatant, class_profile: Resource, run_state: Variant) -> Dictionary:
	var index: int = flex_slot_index(slot_id)
	if index < 0:
		return _slot_hover(slot_id, &"empty", "?", "Invalid Flex Slot", "This is not a class flex slot.")
	if index >= run_state.unlocked_flex_slots:
		return _locked_slot(slot_id, "L", "Locked Flex Skill", "Unlock flex slots from class milestones, events, or class tree rewards.", _primary_resource_keywords(class_profile))
	if index >= run_state.visible_flex_skill_ids.size() or run_state.visible_flex_skill_ids[index] == &"":
		run_state.reroll_flex_slots(class_profile)
	var skill_id: StringName = run_state.visible_flex_skill_ids[index] if index < run_state.visible_flex_skill_ids.size() else &""
	var skill: Resource = class_profile.call("get_skill", skill_id) as Resource
	if skill == null:
		return _disabled_slot(slot_id, "?", "Missing Flex Skill", "This flex slot references a missing class skill.", [], null)
	return _action_slot(slot_id, skill as PlayerActionData, actor, {
		"label": _label_for_skill(skill),
		"skill_id": StringName(str(skill.get("class_skill_id"))),
		"resource": skill,
	})

static func _consumable_slot(slot_id: StringName, run_state: Variant) -> Dictionary:
	var index: int = int(String(slot_id).get_slice("_", 1)) - 1
	if index >= run_state.unlocked_consumable_slots:
		return _locked_slot(slot_id, "L", "Locked Consumable Slot", "Unlock more consumable slots from run rewards or class progression.", [])
	return _disabled_slot(slot_id, "", "Empty Consumable Slot", "No consumable is equipped in this slot.", [], null)

static func _action_slot(slot_id: StringName, action: PlayerActionData, actor: Combatant, extra: Dictionary = {}) -> Dictionary:
	if action == null:
		return _disabled_slot(slot_id, "?", "Missing Action", "This class slot has no action resource.", [], null)
	var reason: String = ActionCostServiceScript.usability_error(actor, action)
	if not reason.is_empty():
		var disabled: Dictionary = _disabled_slot(
			slot_id,
			str(extra.get("label", _label_for_action(action))),
			action.display_name,
			reason,
			action.hover_keywords,
			action
		)
		disabled["action"] = action
		disabled["action_id"] = action.id
		return disabled
	var entry: Dictionary = {
		"slot_id": slot_id,
		"kind": &"action",
		"action": action,
		"action_id": action.id,
		"label": str(extra.get("label", _label_for_action(action))),
		"display_name": action.display_name,
		"description": action.description,
		"resource": extra.get("resource", action),
	}
	for key in extra.keys():
		entry[key] = extra[key]
	return entry

static func _locked_slot(slot_id: StringName, label: String, title: String, description: String, keyword_ids: Array[StringName]) -> Dictionary:
	return _slot_hover(slot_id, &"locked", label, title, description, keyword_ids)

static func _disabled_slot(slot_id: StringName, label: String, title: String, description: String, keyword_ids: Array[StringName], resource: Resource) -> Dictionary:
	var entry: Dictionary = _slot_hover(slot_id, &"disabled", label, title, description, keyword_ids)
	if resource != null:
		entry["resource"] = resource
	return entry

static func _slot_hover(slot_id: StringName, kind: StringName, label: String, title: String, description: String, keyword_ids: Array[StringName] = []) -> Dictionary:
	var info: Resource = HoverInfoDataScript.new()
	info.title = title.strip_edges()
	info.description = description.strip_edges()
	info.keyword_ids.append_array(keyword_ids)
	info.panel_style = kind
	return {
		"slot_id": slot_id,
		"kind": kind,
		"label": label,
		"display_name": title,
		"description": description,
		"hover_info": info,
	}

static func _slot_kind(entry: Dictionary) -> StringName:
	return HotbarSlotSchemaScript.slot_kind(entry)

static func _label_for_action(action: CombatActionData) -> String:
	if action == null:
		return "?"
	if not action.display_name.strip_edges().is_empty():
		return action.display_name.substr(0, 1).to_upper()
	return "?"

static func _label_for_skill(skill: Resource) -> String:
	var display_name := str(skill.get("display_name")).strip_edges()
	if not display_name.is_empty():
		return display_name.substr(0, 1).to_upper()
	return _label_for_action(skill as CombatActionData)

static func _keyword_array(value: Variant) -> Array[StringName]:
	return ValueReaderScript.string_name_array(value)

static func _primary_resource_keywords(class_profile: Resource) -> Array[StringName]:
	var resource_id := StringName(str(class_profile.get("primary_resource_id"))) if class_profile != null else &""
	if resource_id == &"":
		return []
	var resource_data: Resource = null
	if class_profile.has_method("get_class_resource"):
		resource_data = class_profile.call("get_class_resource", resource_id) as Resource
	if resource_data != null and resource_data.has_method("resolved_keyword_id"):
		return [resource_data.call("resolved_keyword_id")]
	return [StringName("resource.%s" % String(resource_id))]
