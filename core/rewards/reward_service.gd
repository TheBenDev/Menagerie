## Reward service for calculating combat rewards and applying reward-shaped results to run data.
class_name RewardService
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

static func empty_reward_result() -> Dictionary:
	return {
		"memories_awarded": 0,
		"gold_awarded": 0,
	}

static func normalize_reward_result(reward_result: Variant) -> Dictionary:
	var normalized := empty_reward_result()
	if reward_result == null:
		return normalized

	normalized["memories_awarded"] = max(ValueReaderScript.variant_int(reward_result, "memories_awarded", 0), 0)
	normalized["gold_awarded"] = max(ValueReaderScript.variant_int(reward_result, "gold_awarded", 0), 0)
	return normalized

static func apply_reward_result(run_data: Variant, reward_result: Variant) -> Dictionary:
	var normalized := normalize_reward_result(reward_result)
	if run_data != null and run_data.has_method("grant_rewards"):
		#; Combat rewards are party-wide run progress; limited-use event effects will add usage metadata later.
		run_data.grant_rewards(
			int(normalized.get("memories_awarded", 0)),
			int(normalized.get("gold_awarded", 0))
		)

	return normalized

static func calculate_combat_rewards(profile: Resource, difficulty_profile: Resource, is_boss: bool) -> Dictionary:
	var rewards := empty_reward_result()
	if profile == null:
		return rewards

	var reward_profile: Resource = profile.get("reward_profile") as Resource
	if reward_profile == null:
		return rewards

	var difficulty_multiplier := ValueReaderScript.resource_float(difficulty_profile, "reward_multiplier", 1.0)
	var encounter_multiplier := 1.0
	if is_boss:
		encounter_multiplier = ValueReaderScript.resource_float(reward_profile, "boss_multiplier", 4.0)

	var reward_multiplier := difficulty_multiplier * encounter_multiplier
	rewards["memories_awarded"] = max(
		int(round(ValueReaderScript.resource_float(reward_profile, "base_memories", 0.0) * reward_multiplier)),
		0
	)
	rewards["gold_awarded"] = max(
		int(round(ValueReaderScript.resource_float(reward_profile, "base_gold", 0.0) * reward_multiplier)),
		0
	)
	return rewards

static func calculate_combat_rewards_for_profiles(profiles: Array, difficulty_profile: Resource, is_boss: bool) -> Dictionary:
	var rewards := empty_reward_result()
	for profile in profiles:
		var profile_rewards := calculate_combat_rewards(profile as Resource, difficulty_profile, is_boss)
		rewards["memories_awarded"] = int(rewards.get("memories_awarded", 0)) + int(profile_rewards.get("memories_awarded", 0))
		rewards["gold_awarded"] = int(rewards.get("gold_awarded", 0)) + int(profile_rewards.get("gold_awarded", 0))

	return rewards
