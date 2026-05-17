## Player run-state helper for profile stat snapshots, persistent HP, and combatant bridge setup.
class_name PlayerRunStateService
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

const STAT_STRENGTH := "STR"
const STAT_DEXTERITY := "DEX"
const STAT_INTELLIGENCE := "INT"
const STAT_VITALITY := "VIT"

static func hp_snapshot(run_data: Variant) -> Dictionary:
	if run_data == null:
		return {
			"current": 0,
			"max": 0,
		}

	return {
		"current": run_data.player_current_hp,
		"max": run_data.player_max_hp,
	}

static func effective_player_stats(run_data: Variant, fallback_profile: Resource) -> Dictionary:
	if run_data != null:
		return run_data.get_effective_stats()

	return base_profile_stats(fallback_profile, 0)

static func base_profile_stats(profile: Resource, default_value: int = 5) -> Dictionary:
	return {
		STAT_STRENGTH: ValueReaderScript.resource_int(profile, "strength", default_value),
		STAT_DEXTERITY: ValueReaderScript.resource_int(profile, "dexterity", default_value),
		STAT_INTELLIGENCE: ValueReaderScript.resource_int(profile, "intelligence", default_value),
		STAT_VITALITY: ValueReaderScript.resource_int(profile, "vitality", default_value),
	}

static func apply_run_state_to_combatant(run_data: Variant, combatant: Variant) -> void:
	if run_data == null or combatant == null:
		return

	run_data.apply_player_stats_to_combatant(combatant)
