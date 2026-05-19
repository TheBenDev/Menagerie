## Reward service for calculating combat rewards and applying reward-shaped results to run data.
class_name RewardService
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

## Returns a normalized package shape used by all reward producers and consumers.
static func empty_reward_package() -> Dictionary:
	return {
		"party": {
			"memories": 0,
			"gold": 0,
		},
		"members": {},
		"metadata": {
			"source": &"",
			"source_id": &"",
			"is_boss": false,
		},
	}

## Calculates the complete reward package for a resolved combat.
static func calculate_combat_reward_package(
	enemy_instances: Array,
	profiles: Array,
	is_boss: bool,
	source_id: StringName = &""
) -> Dictionary:
	var package := empty_reward_package()
	package["metadata"] = {
		"source": &"combat",
		"source_id": source_id,
		"is_boss": is_boss,
		"enemy_count": profiles.size(),
		"enemy_levels": _enemy_levels(enemy_instances),
		"enemy_profile_paths": _enemy_profile_paths(profiles),
	}

	var party_rewards: Dictionary = package.get("party", {})
	for profile in profiles:
		var profile_rewards := _calculate_profile_rewards(profile as Resource, is_boss)
		party_rewards["memories"] = int(party_rewards.get("memories", 0)) + int(profile_rewards.get("memories", 0))
		party_rewards["gold"] = int(party_rewards.get("gold", 0)) + int(profile_rewards.get("gold", 0))

	package["party"] = party_rewards
	return package

## Applies party-level reward totals to run currency state.
static func apply_reward_package_to_run(run_data: Variant, reward_package: Dictionary) -> Dictionary:
	var package: Dictionary = normalized_reward_package(reward_package)
	if run_data != null and run_data.has_method("add_currencies"):
		var party_rewards: Dictionary = package.get("party", {})
		run_data.add_currencies(
			int(party_rewards.get("memories", 0)),
			int(party_rewards.get("gold", 0))
		)

	return package

## Exports run memories exactly once into persistent class-award storage.
static func export_run_memories_to_class_awards(run_data: Variant, class_memory_awards: Dictionary) -> int:
	if run_data == null or run_data.memories_exported:
		return 0

	var awarded_memories: int = max(int(run_data.memories), 0)
	if awarded_memories <= 0:
		return 0

	var character_id: String = str(run_data.selected_character)
	var current_total: int = int(class_memory_awards.get(character_id, 0))
	class_memory_awards[character_id] = current_total + awarded_memories
	run_data.memories_exported = true
	return awarded_memories

static func normalized_reward_package(reward_package: Variant) -> Dictionary:
	var package: Dictionary = empty_reward_package()
	if not (reward_package is Dictionary):
		return package

	var raw_package: Dictionary = reward_package
	var raw_party: Variant = raw_package.get("party", {})
	if raw_party is Dictionary:
		var party_rewards: Dictionary = raw_party
		package["party"] = {
			"memories": max(int(party_rewards.get("memories", 0)), 0),
			"gold": max(int(party_rewards.get("gold", 0)), 0),
		}
	var raw_members: Variant = raw_package.get("members", {})
	if raw_members is Dictionary:
		package["members"] = raw_members.duplicate(true)
	var raw_metadata: Variant = raw_package.get("metadata", {})
	if raw_metadata is Dictionary:
		package["metadata"] = raw_metadata.duplicate(true)
	return package

static func _calculate_profile_rewards(profile: Resource, is_boss: bool) -> Dictionary:
	var rewards := {
		"memories": 0,
		"gold": 0,
	}
	if profile == null:
		return rewards

	var reward_profile: Resource = profile.get("reward_profile") as Resource
	if reward_profile == null:
		return rewards

	var encounter_multiplier := 1.0
	if is_boss:
		encounter_multiplier = ValueReaderScript.resource_float(reward_profile, "boss_multiplier", 4.0)

	rewards["memories"] = max(
		int(round(ValueReaderScript.resource_float(reward_profile, "base_memories", 0.0) * encounter_multiplier)),
		0
	)
	rewards["gold"] = max(
		int(round(ValueReaderScript.resource_float(reward_profile, "base_gold", 0.0) * encounter_multiplier)),
		0
	)
	return rewards

static func _enemy_levels(enemy_instances: Array) -> Array[int]:
	var levels: Array[int] = []
	for raw_instance in enemy_instances:
		if raw_instance is Dictionary:
			levels.append(int(raw_instance.get("level", 0)))
	return levels

static func _enemy_profile_paths(profiles: Array) -> Array[String]:
	var profile_paths: Array[String] = []
	for raw_profile in profiles:
		var profile := raw_profile as Resource
		if profile != null and not profile.resource_path.is_empty():
			profile_paths.append(profile.resource_path)
	return profile_paths
