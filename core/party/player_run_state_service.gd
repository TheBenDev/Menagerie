## Player run-state helper for profile stat snapshots, persistent HP, and combatant bridge setup.
class_name PlayerRunStateService
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const StatId := preload("res://core/combat/stat_id.gd")

static func hp_snapshot(run_data: Variant) -> Dictionary:
	if run_data == null:
		return {
			"current": 0,
			"max": 0,
		}
	if run_data.has_method("get_player_hp_snapshot"):
		return run_data.get_player_hp_snapshot()

	return {
		"current": 0,
		"max": 0,
	}

static func effective_player_stats(run_data: Variant, fallback_profile: Resource) -> Dictionary:
	if run_data != null:
		return run_data.get_effective_stats()

	return base_profile_stats(fallback_profile, 0)

static func base_profile_stats(profile: Resource, default_value: int = 5) -> Dictionary:
	var stats: Dictionary = {}
	for stat_id in StatId.ALL:
		var field_name := str(StatId.PROFILE_FIELD_BY_ID.get(stat_id, ""))
		stats[stat_id] = ValueReaderScript.resource_int(profile, field_name, default_value)
	return stats

static func apply_run_state_to_combatant(run_data: Variant, combatant: Variant) -> void:
	if run_data == null or combatant == null:
		return

	run_data.apply_player_stats_to_combatant(combatant)
