## Shared service for generating, rolling, snapshotting, and applying class rewards.
class_name ClassRewardService
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const ClassRarityScript := preload("res://core/combat/classes/class_rarity.gd")
const ClassRunStateScript := preload("res://core/combat/classes/class_run_state.gd")
const ClassProfileDataScript := preload("res://core/combat/classes/class_profile_data.gd")

const SOURCE_HAVEN := "haven"
const SOURCE_MEMORY := "memory"

const TYPE_NEW_SKILL := &"new_skill"
const TYPE_PASSIVE := &"passive"
const TYPE_SKILL_UPGRADE := &"skill_upgrade"
const TYPE_STANCE_UNLOCK := &"stance_unlock"
const TYPE_SLOT_UNLOCK := &"slot_unlock"

const REWARD_ID_FLEX_SLOT := &"slot.flex"
const FLEX_SLOT_UNLOCK_AMOUNT := 1

static func prepare_haven_reward(run_data: Variant, node_id: int = -1) -> bool:
	var state: Variant = _selected_class_state(run_data)
	var profile: Resource = _selected_class_profile(run_data)
	if state == null or profile == null:
		return false
	if state.has_pending_reward():
		return false
	var options: Array[Dictionary] = _roll_haven_rewards(profile, state, 2)
	if options.size() < 2:
		push_error("Class Haven reward needs 2 valid options, got %s." % options.size())
		return false
	_set_pending_reward(run_data, state, SOURCE_HAVEN, options, 0, node_id)
	return true

static func prepare_memory_reward_if_ready(run_data: Variant) -> bool:
	var state: Variant = _selected_class_state(run_data)
	var profile: Resource = _selected_class_profile(run_data)
	if state == null or profile == null:
		return false
	if state.has_pending_reward():
		return false
	var cost: int = int(profile.next_memory_cost(state.memory_level))
	if int(run_data.memories) < cost:
		return false
	var options: Array[Dictionary] = _roll_memory_rewards(profile, state, 3)
	if options.size() < 3:
		push_error("Class memory reward needs 3 valid options, got %s." % options.size())
		return false
	_set_pending_reward(run_data, state, SOURCE_MEMORY, options, cost, -1)
	return true

static func apply_pending_reward(run_data: Variant, context_id: String, reward_id: StringName) -> Dictionary:
	var state: Variant = _selected_class_state(run_data)
	var profile: Resource = _selected_class_profile(run_data)
	if state == null or profile == null:
		return {"accepted": false, "reason": "missing_class_state"}
	var pending: Dictionary = state.pending_reward_context
	if pending.is_empty():
		return {"accepted": false, "reason": "no_pending_class_reward"}
	if str(pending.get("context_id", "")) != context_id:
		return {"accepted": false, "reason": "class_reward_context_mismatch"}
	var option_ids: Array[StringName] = ValueReaderScript.string_name_array(pending.get("option_reward_ids", []))
	if not option_ids.has(reward_id):
		return {"accepted": false, "reason": "class_reward_not_offered"}

	var catalog: Dictionary = _reward_catalog(profile)
	var reward: Dictionary = catalog.get(reward_id, {})
	if reward.is_empty():
		push_error("Pending class reward %s no longer exists in the generated catalog." % reward_id)
		return {"accepted": false, "reason": "missing_class_reward"}
	var source: String = str(pending.get("source", ""))
	if not _is_reward_eligible(reward, profile, state, source):
		push_error("Pending class reward %s is no longer eligible." % reward_id)
		return {"accepted": false, "reason": "class_reward_no_longer_eligible"}

	var cost: int = int(pending.get("memory_cost", 0))
	if source == SOURCE_MEMORY:
		if run_data == null or not run_data.has_method("spend_memories") or not run_data.spend_memories(cost):
			return {"accepted": false, "reason": "not_enough_memories"}
		state.memory_level += 1
	_apply_reward(reward, profile, state)
	state.clear_pending_reward()
	if source == SOURCE_MEMORY:
		prepare_memory_reward_if_ready(run_data)
	return {"accepted": true, "reason": "class_reward_applied"}

static func pending_reward_snapshot(run_data: Variant) -> Dictionary:
	var state: Variant = _selected_class_state(run_data)
	var profile: Resource = _selected_class_profile(run_data)
	if state == null or profile == null or state.pending_reward_context.is_empty():
		return {}
	var pending: Dictionary = state.pending_reward_context.duplicate(true)
	var catalog: Dictionary = _reward_catalog(profile)
	var option_snapshots: Array[Dictionary] = []
	for reward_id in ValueReaderScript.string_name_array(pending.get("option_reward_ids", [])):
		var reward: Dictionary = catalog.get(reward_id, {})
		if reward.is_empty():
			push_error("Pending class reward references missing generated option %s." % reward_id)
			continue
		option_snapshots.append(_reward_snapshot(reward))
	pending["options"] = option_snapshots
	return pending

static func memory_progress_snapshot(run_data: Variant) -> Dictionary:
	var state: Variant = _selected_class_state(run_data)
	var profile: Resource = _selected_class_profile(run_data)
	if state == null or profile == null or run_data == null:
		return {}
	var next_cost: int = int(profile.next_memory_cost(state.memory_level))
	return {
		"current": max(int(run_data.memories), 0),
		"next_cost": next_cost,
		"memory_level": state.memory_level,
		"pending_reward": state.has_pending_reward(),
	}

static func _set_pending_reward(run_data: Variant, state: Variant, source: String, rewards: Array[Dictionary], memory_cost: int, node_id: int) -> void:
	state.pending_reward_context = {
		"context_id": "%s_%s_%s" % [source, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()],
		"source": source,
		"member_id": _selected_member_id(run_data),
		"owner_peer_id": _selected_owner_peer_id(run_data),
		"option_reward_ids": _reward_ids(rewards),
		"memory_cost": max(memory_cost, 0),
		"node_id": node_id,
	}

static func _roll_haven_rewards(profile: Resource, state: Variant, count: int) -> Array[Dictionary]:
	var stance_rewards: Array[Dictionary] = _eligible_rewards_by_type(profile, state, SOURCE_HAVEN, ClassRarityScript.RARE, TYPE_STANCE_UNLOCK)
	var picked: Array[Dictionary] = _pick_unique_rewards(stance_rewards, min(count, stance_rewards.size()))
	if picked.size() >= count:
		return picked
	var eligible: Array[Dictionary] = _without_rewards(_eligible_rewards(profile, state, SOURCE_HAVEN, ClassRarityScript.RARE), picked)
	picked.append_array(_pick_unique_rewards(eligible, count - picked.size()))
	return picked

static func _roll_memory_rewards(profile: Resource, state: Variant, count: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	for index in range(count):
		var rarity: StringName = _roll_rarity(profile)
		var eligible: Array[Dictionary] = _eligible_rewards(profile, state, SOURCE_MEMORY, rarity)
		if eligible.is_empty():
			eligible = _eligible_rewards(profile, state, SOURCE_MEMORY, &"")
		eligible = _without_rewards(eligible, rewards)
		if eligible.is_empty():
			push_error("No valid class memory rewards remain for option %s." % index)
			break
		rewards.append(eligible.pick_random())
	return rewards

static func _eligible_rewards(profile: Resource, state: Variant, source: String, rarity: StringName) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	var catalog: Dictionary = _reward_catalog(profile)
	for raw_reward in catalog.values():
		if not (raw_reward is Dictionary):
			continue
		var reward: Dictionary = raw_reward
		if rarity != &"" and _reward_rarity(reward) != rarity:
			continue
		if _is_reward_eligible(reward, profile, state, source):
			eligible.append(reward)
	return eligible

static func _eligible_rewards_by_type(
	profile: Resource,
	state: Variant,
	source: String,
	rarity: StringName,
	reward_type: StringName
) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for reward in _eligible_rewards(profile, state, source, rarity):
		if _reward_type(reward) == reward_type:
			eligible.append(reward)
	return eligible

static func _is_reward_eligible(reward: Dictionary, profile: Resource, state: Variant, source: String) -> bool:
	var reward_type: StringName = _reward_type(reward)
	if source == SOURCE_HAVEN and state.unlocked_stance_ids.is_empty() and reward_type != TYPE_STANCE_UNLOCK:
		return false
	match reward_type:
		TYPE_STANCE_UNLOCK:
			var stance_id: StringName = _linked_id(reward)
			return stance_id != &"" and profile.get_stance(stance_id) != null and not state.unlocked_stance_ids.has(stance_id)
		TYPE_NEW_SKILL:
			var skill_id: StringName = _linked_id(reward)
			var skill: Resource = profile.get_skill(skill_id) as Resource
			if skill == null or state.skillbook_ids.has(skill_id):
				return false
			if _fixed_stance_skill_ids(profile).has(skill_id):
				return false
			if not bool(skill.get("valid_as_flex_skill")):
				return false
			var skill_stance_id: StringName = StringName(str(skill.get("stance_id")))
			return skill_stance_id == &"" or state.unlocked_stance_ids.has(skill_stance_id)
		TYPE_PASSIVE:
			var passive_id: StringName = _linked_id(reward)
			var passive: Resource = profile.get_passive(passive_id) as Resource
			if passive_id == &"" or passive == null or state.passive_ids.has(passive_id):
				return false
			return _stance_requirements_are_met(_required_stance_ids(passive, profile), state)
		TYPE_SKILL_UPGRADE:
			var upgrade_id: StringName = _linked_id(reward)
			var upgrade: Resource = profile.get_upgrade(upgrade_id) as Resource
			if upgrade == null or state.upgrade_ids.has(upgrade_id):
				return false
			if upgrade.target_skill_id != &"" and not state.skillbook_ids.has(upgrade.target_skill_id):
				return false
			if upgrade.target_stance_id != &"" and not state.unlocked_stance_ids.has(upgrade.target_stance_id):
				return false
			return true
		TYPE_SLOT_UNLOCK:
			if source != SOURCE_MEMORY or state.unlocked_flex_slots >= ClassRunStateScript.MAX_FLEX_SLOTS:
				return false
			var slots_after_unlock: int = min(
				ClassRunStateScript.MAX_FLEX_SLOTS,
				state.unlocked_flex_slots + max(int(reward.get("flex_slots_unlocked", FLEX_SLOT_UNLOCK_AMOUNT)), 1)
			)
			return _valid_flex_skill_count(profile, state) >= slots_after_unlock
		_:
			return false

static func _apply_reward(reward: Dictionary, profile: Resource, state: Variant) -> void:
	match _reward_type(reward):
		TYPE_STANCE_UNLOCK:
			var stance_id: StringName = _linked_id(reward)
			var is_starter: bool = state.unlocked_stance_ids.is_empty()
			state.unlock_stance(stance_id, profile, is_starter)
			_learn_first_fixed_stance_skill(stance_id, profile, state)
			if is_starter:
				state.reroll_flex_slots(profile)
		TYPE_NEW_SKILL:
			state.learn_skill(_linked_id(reward), profile)
			state.reroll_flex_slots(profile)
		TYPE_PASSIVE:
			state.add_passive(_linked_id(reward), profile)
		TYPE_SKILL_UPGRADE:
			state.add_upgrade(_linked_id(reward), profile)
		TYPE_SLOT_UNLOCK:
			state.unlock_flex_slots(int(reward.get("flex_slots_unlocked", FLEX_SLOT_UNLOCK_AMOUNT)))
			state.reroll_flex_slots(profile)
		_:
			push_error("Unsupported class reward type: %s." % _reward_type(reward))

static func _reward_catalog(profile: Resource) -> Dictionary:
	var catalog: Dictionary = {}
	if profile == null:
		return catalog
	_add_stance_unlock_rewards(catalog, profile)
	_add_skill_rewards(catalog, profile)
	_add_passive_rewards(catalog, profile)
	_add_upgrade_rewards(catalog, profile)
	_add_flex_slot_reward(catalog)
	return catalog

static func _add_stance_unlock_rewards(catalog: Dictionary, profile: Resource) -> void:
	for raw_stance_id in profile.stance_ids():
		var stance_id: StringName = StringName(str(raw_stance_id))
		var stance: Resource = profile.get_stance(stance_id) as Resource
		if stance == null:
			continue
		var reward_id: StringName = StringName("stance_unlock.%s" % String(stance_id))
		_add_catalog_entry(catalog, reward_id, TYPE_STANCE_UNLOCK, _resource_rarity(stance, "unlock_rarity", ClassRarityScript.RARE), stance_id, stance, 0)

static func _add_skill_rewards(catalog: Dictionary, profile: Resource) -> void:
	var fixed_skill_ids: Dictionary = _fixed_stance_skill_ids(profile)
	for action in profile.actions():
		if action == null:
			continue
		var skill_id: StringName = StringName(str(action.get("class_skill_id")))
		if skill_id == &"" or fixed_skill_ids.has(skill_id) or not bool(action.get("valid_as_flex_skill")):
			continue
		var reward_id: StringName = StringName("skill.%s" % String(skill_id))
		_add_catalog_entry(catalog, reward_id, TYPE_NEW_SKILL, _resource_rarity(action, "skill_rarity", ClassRarityScript.COMMON), skill_id, action, 0)

static func _add_passive_rewards(catalog: Dictionary, profile: Resource) -> void:
	for raw_passive in profile.passives():
		var passive: Resource = raw_passive as Resource
		if passive == null:
			continue
		var passive_id: StringName = StringName(str(passive.get("id")))
		if passive_id == &"":
			continue
		var reward_id: StringName = StringName("passive.%s" % String(passive_id))
		_add_catalog_entry(catalog, reward_id, TYPE_PASSIVE, _resource_rarity(passive, "rarity", ClassRarityScript.UNCOMMON), passive_id, passive, 0)

static func _add_upgrade_rewards(catalog: Dictionary, profile: Resource) -> void:
	for raw_upgrade in profile.upgrades():
		var upgrade: Resource = raw_upgrade as Resource
		if upgrade == null:
			continue
		var upgrade_id: StringName = StringName(str(upgrade.get("id")))
		if upgrade_id == &"":
			continue
		var reward_id: StringName = StringName("upgrade.%s" % String(upgrade_id))
		_add_catalog_entry(catalog, reward_id, TYPE_SKILL_UPGRADE, _resource_rarity(upgrade, "rarity", ClassRarityScript.UNCOMMON), upgrade_id, upgrade, 0)

static func _add_flex_slot_reward(catalog: Dictionary) -> void:
	catalog[REWARD_ID_FLEX_SLOT] = {
		"reward_id": String(REWARD_ID_FLEX_SLOT),
		"reward_type": TYPE_SLOT_UNLOCK,
		"rarity": ClassRarityScript.COMMON,
		"linked_id": &"",
		"display_name": "Unlock Flex Slot",
		"description": "Unlock one flex skill slot for this run.",
		"tags": [],
		"hover_keywords": [],
		"linked_resource_path": "",
		"linked_display_name": "",
		"flex_slots_unlocked": FLEX_SLOT_UNLOCK_AMOUNT,
	}

static func _add_catalog_entry(
	catalog: Dictionary,
	reward_id: StringName,
	reward_type: StringName,
	rarity: StringName,
	linked_id: StringName,
	linked_resource: Resource,
	flex_slots_unlocked: int
) -> void:
	if reward_id == &"" or linked_id == &"":
		push_error("Generated class reward is missing reward_id or linked_id.")
		return
	if linked_resource == null:
		push_error("Generated class reward %s is missing its linked resource." % reward_id)
		return
	if not ClassRarityScript.is_valid(rarity):
		push_error("Generated class reward %s has invalid rarity %s." % [reward_id, rarity])
		return
	var linked_display_name: String = _resource_display_name(linked_resource, String(linked_id).capitalize())
	catalog[reward_id] = {
		"reward_id": String(reward_id),
		"reward_type": reward_type,
		"rarity": rarity,
		"linked_id": linked_id,
		"display_name": linked_display_name,
		"description": _resource_description(linked_resource),
		"tags": _resource_tags(linked_resource),
		"hover_keywords": _resource_keywords(linked_resource),
		"linked_resource_path": linked_resource.resource_path,
		"linked_display_name": linked_display_name,
		"flex_slots_unlocked": max(flex_slots_unlocked, 0),
	}

static func _reward_snapshot(reward: Dictionary) -> Dictionary:
	return {
		"reward_id": str(reward.get("reward_id", "")),
		"reward_type": String(_reward_type(reward)),
		"rarity": String(_reward_rarity(reward)),
		"linked_id": String(_linked_id(reward)),
		"display_name": str(reward.get("display_name", "")),
		"description": str(reward.get("description", "")),
		"tags": ValueReaderScript.string_array(reward.get("tags", [])),
		"hover_keywords": ValueReaderScript.string_array(reward.get("hover_keywords", [])),
		"linked_resource_path": str(reward.get("linked_resource_path", "")),
		"linked_display_name": str(reward.get("linked_display_name", "")),
		"flex_slots_unlocked": int(reward.get("flex_slots_unlocked", 0)),
	}

static func _learn_first_fixed_stance_skill(stance_id: StringName, profile: Resource, state: Variant) -> void:
	var stance: Resource = profile.get_stance(stance_id) as Resource
	if stance == null:
		push_error("Class stance reward references missing stance %s." % stance_id)
		return
	var fixed_skill_ids: Array[StringName] = ValueReaderScript.string_name_array(stance.get("fixed_skill_ids"))
	if fixed_skill_ids.is_empty():
		push_error("Class stance %s has no fixed skill to unlock." % stance_id)
		return
	state.learn_skill(fixed_skill_ids[0], profile)

static func _valid_flex_skill_count(profile: Resource, state: Variant) -> int:
	if profile == null or state == null:
		return 0
	if state.has_method("valid_flex_skill_ids"):
		return state.valid_flex_skill_ids(profile).size()
	return 0

static func _required_stance_ids(linked_resource: Resource, profile: Resource) -> Array[StringName]:
	var requirements: Array[StringName] = []
	var stance_lookup: Dictionary = {}
	for raw_stance_id in profile.stance_ids():
		stance_lookup[StringName(str(raw_stance_id))] = true
	_append_required_stance_tags(requirements, linked_resource.get("tags") if linked_resource != null else [], stance_lookup)
	return requirements

static func _append_required_stance_tags(requirements: Array[StringName], raw_tags: Variant, stance_lookup: Dictionary) -> void:
	for raw_tag in ValueReaderScript.string_name_array(raw_tags):
		_append_required_stance(requirements, raw_tag, stance_lookup)

static func _append_required_stance(requirements: Array[StringName], stance_id: StringName, stance_lookup: Dictionary) -> void:
	if stance_id == &"" or not stance_lookup.has(stance_id) or requirements.has(stance_id):
		return
	requirements.append(stance_id)

static func _stance_requirements_are_met(requirements: Array[StringName], state: Variant) -> bool:
	for stance_id in requirements:
		if not state.unlocked_stance_ids.has(stance_id):
			return false
	return true

static func _roll_rarity(profile: Resource) -> StringName:
	var total_weight: float = 0.0
	var raw_weights: Variant = profile.get("milestone_rarity_weights")
	if not (raw_weights is Array):
		return ClassRarityScript.COMMON
	for entry in raw_weights:
		if entry is Dictionary:
			total_weight += max(float(entry.get("weight", 0.0)), 0.0)
	if total_weight <= 0.0:
		return ClassRarityScript.COMMON
	var roll: float = randf() * total_weight
	var cursor: float = 0.0
	for entry in raw_weights:
		if not (entry is Dictionary):
			continue
		cursor += max(float(entry.get("weight", 0.0)), 0.0)
		if roll <= cursor:
			return StringName(str(entry.get("rarity", ClassRarityScript.COMMON)))
	return ClassRarityScript.COMMON

static func _pick_unique_rewards(rewards: Array[Dictionary], count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = rewards.duplicate()
	var picked: Array[Dictionary] = []
	while picked.size() < count and not pool.is_empty():
		var picked_index: int = randi() % pool.size()
		picked.append(pool[picked_index])
		pool.remove_at(picked_index)
	return picked

static func _without_rewards(rewards: Array[Dictionary], excluded: Array[Dictionary]) -> Array[Dictionary]:
	var excluded_ids: Dictionary = {}
	for reward in excluded:
		excluded_ids[str(reward.get("reward_id", ""))] = true
	var result: Array[Dictionary] = []
	for reward in rewards:
		if not excluded_ids.has(str(reward.get("reward_id", ""))):
			result.append(reward)
	return result

static func _reward_ids(rewards: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for reward in rewards:
		var reward_id: String = str(reward.get("reward_id", "")).strip_edges()
		if not reward_id.is_empty():
			ids.append(reward_id)
	return ids

static func _fixed_stance_skill_ids(profile: Resource) -> Dictionary:
	var ids: Dictionary = {}
	if profile == null:
		return ids
	for raw_stance_id in profile.stance_ids():
		var stance_id: StringName = StringName(str(raw_stance_id))
		var stance: Resource = profile.get_stance(stance_id) as Resource
		if stance == null:
			continue
		for skill_id in ValueReaderScript.string_name_array(stance.get("fixed_skill_ids")):
			ids[skill_id] = true
	return ids

static func _reward_type(reward: Dictionary) -> StringName:
	return StringName(str(reward.get("reward_type", &"")))

static func _reward_rarity(reward: Dictionary) -> StringName:
	return StringName(str(reward.get("rarity", &"")))

static func _linked_id(reward: Dictionary) -> StringName:
	return StringName(str(reward.get("linked_id", &"")))

static func _resource_rarity(resource: Resource, property_name: String, default_rarity: StringName) -> StringName:
	if resource == null:
		return default_rarity
	var rarity: StringName = StringName(str(resource.get(property_name)))
	if ClassRarityScript.is_valid(rarity):
		return rarity
	push_error("%s has invalid reward rarity %s." % [resource.resource_path, rarity])
	return &""

static func _resource_display_name(resource: Resource, default_name: String) -> String:
	if resource == null:
		return default_name
	var value: String = str(resource.get("display_name")).strip_edges()
	return value if not value.is_empty() else default_name

static func _resource_description(resource: Resource) -> String:
	if resource == null:
		return ""
	var description: String = str(resource.get("description")).strip_edges()
	if not description.is_empty():
		return description
	var tooltip_value: Variant = resource.get("tooltip_text")
	return str(tooltip_value).strip_edges() if tooltip_value != null else ""

static func _resource_tags(resource: Resource) -> Array[StringName]:
	if resource == null:
		return []
	var raw_tags: Variant = resource.get("tags")
	if raw_tags is Array and not raw_tags.is_empty():
		return ValueReaderScript.string_name_array(raw_tags)
	return ValueReaderScript.string_name_array(resource.get("skill_tags"))

static func _resource_keywords(resource: Resource) -> Array[StringName]:
	if resource == null:
		return []
	return ValueReaderScript.string_name_array(resource.get("hover_keywords"))

static func _selected_class_state(run_data: Variant) -> Variant:
	var party_manager: Node = Engine.get_main_loop().root.get_node_or_null("PartyManager")
	if party_manager == null or not party_manager.has_method("get_selected_member_class_run_state"):
		return null
	var state: Variant = party_manager.get_selected_member_class_run_state(run_data)
	if state != null and state.get_script() == ClassRunStateScript:
		return state
	return null

static func _selected_class_profile(run_data: Variant) -> Resource:
	var party_manager: Node = Engine.get_main_loop().root.get_node_or_null("PartyManager")
	if party_manager == null:
		return null
	if not party_manager.has_method("get_selected_member_class_profile"):
		push_error("PartyManager.get_selected_member_class_profile is required for class rewards.")
		return null
	var class_profile: Resource = party_manager.get_selected_member_class_profile(run_data) as Resource
	if class_profile != null and class_profile.get_script() == ClassProfileDataScript:
		return class_profile
	return null

static func _selected_member_id(run_data: Variant) -> String:
	if run_data == null or run_data.player_party_state == null:
		return ""
	return str(run_data.player_party_state.selected_member_id)

static func _selected_owner_peer_id(run_data: Variant) -> int:
	if run_data == null or run_data.player_party_state == null:
		return 1
	var member: Variant = run_data.player_party_state.get_selected_member()
	return int(member.owner_peer_id) if member != null else 1
