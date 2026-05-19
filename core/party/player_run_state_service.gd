## Player run-state helper for profile stat snapshots, persistent HP, and combatant bridge setup.
class_name PlayerRunStateService
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

## Returns the currently selected persistent combatant state for the run.
static func selected_combatant_state(run_data: Variant) -> Variant:
	if run_data == null or run_data.player_party_state == null:
		return null

	return run_data.player_party_state.get_selected_combatant_state()

## Copies active run modifiers into the selected persistent combatant state.
static func sync_modifiers(run_data: Variant) -> void:
	var combatant_state: Variant = selected_combatant_state(run_data)
	if combatant_state == null:
		return

	combatant_state.set_runtime_modifiers(run_data.run_stat_modifiers)

static func hp_snapshot(run_data: Variant) -> Dictionary:
	var combatant_state: Variant = selected_combatant_state(run_data)
	if combatant_state != null:
		return {
			"current": int(combatant_state.current_hp),
			"max": int(combatant_state.max_hp),
		}

	return {
		"current": 0,
		"max": 0,
	}

static func effective_player_stats(run_data: Variant, fallback_profile: Resource) -> Dictionary:
	var combatant_state: Variant = selected_combatant_state(run_data)
	if combatant_state != null:
		sync_modifiers(run_data)
		return combatant_state.get_effective_stats()

	return base_profile_stats(fallback_profile, 0)

static func base_profile_stats(profile: Resource, default_value: int = 5) -> Dictionary:
	var stats: Dictionary = {}
	for stat_id: String in StatId.ALL:
		var field_name := str(StatId.PROFILE_FIELD_BY_ID.get(stat_id, ""))
		stats[stat_id] = ValueReaderScript.resource_int(profile, field_name, default_value)
	return stats

static func apply_run_state_to_combatant(run_data: Variant, combatant: Variant) -> void:
	if run_data == null or combatant == null:
		return

	var combatant_state: Variant = selected_combatant_state(run_data)
	if combatant_state == null:
		return

	sync_modifiers(run_data)
	combatant_state.apply_stats_to_combatant(combatant)

## Applies persistent HP to the selected member state.
static func set_selected_hp(run_data: Variant, current_hp: int, max_hp: int = -1) -> void:
	var combatant_state: Variant = selected_combatant_state(run_data)
	if combatant_state == null:
		return

	if max_hp > 0:
		combatant_state.set_max_hp(max_hp, false)
	combatant_state.set_current_hp(current_hp)

## Applies damage and returns the actual HP lost.
static func apply_damage(run_data: Variant, amount: int) -> int:
	var hp_before: Dictionary = hp_snapshot(run_data)
	var previous_hp: int = int(hp_before.get("current", 0))
	set_selected_hp(run_data, previous_hp - max(amount, 0), int(hp_before.get("max", 0)))
	return max(previous_hp - int(hp_snapshot(run_data).get("current", 0)), 0)

## Adds a run-scoped stat modifier and refreshes derived HP state.
static func add_stat_modifier(
	run_data: Variant,
	stat_id: String,
	amount: int,
	permanent: bool,
	duration_seconds: float
) -> bool:
	if run_data == null or amount == 0:
		return false
	if not permanent and duration_seconds <= 0.0:
		return false

	run_data.run_stat_modifiers.append({
		"stat_id": StatId.from_value(stat_id),
		"amount": amount,
		"permanent": permanent,
		"remaining_seconds": duration_seconds,
	})
	sync_modifiers(run_data)
	recalculate_selected_max_hp(run_data, false)
	return true

## Ticks temporary run modifiers after run time advances.
static func tick_modifiers(run_data: Variant, seconds: float) -> void:
	if run_data == null or seconds <= 0.0 or run_data.run_stat_modifiers.is_empty():
		return

	var active_modifiers: Array[Dictionary] = []
	for modifier in run_data.run_stat_modifiers:
		if bool(modifier.get("permanent", false)):
			active_modifiers.append(modifier)
			continue

		var remaining_seconds: float = float(modifier.get("remaining_seconds", 0.0)) - seconds
		if remaining_seconds > 0.0:
			modifier["remaining_seconds"] = remaining_seconds
			active_modifiers.append(modifier)

	run_data.run_stat_modifiers = active_modifiers
	sync_modifiers(run_data)
	recalculate_selected_max_hp(run_data, false)

## Recalculates selected member max HP from effective vitality.
static func recalculate_selected_max_hp(run_data: Variant, heal_to_full: bool) -> void:
	sync_modifiers(run_data)
	var combatant_state: Variant = selected_combatant_state(run_data)
	if combatant_state == null:
		return

	combatant_state.recalculate_max_hp(heal_to_full)

static func is_player_defeated(run_data: Variant) -> bool:
	return int(hp_snapshot(run_data).get("current", 0)) <= 0
