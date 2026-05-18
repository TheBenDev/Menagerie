## Stores persistent runtime combat data for any character or enemy that can participate in combat.
class_name CombatantState
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

var combatant_id: String = ""
var profile_path: String = ""
var display_name: String = "Combatant"
var current_hp: int = 0
var max_hp: int = 0
var stats: Dictionary = {}
var statuses: Dictionary = {}
var is_alive: bool = true
var runtime_modifiers: Array[Dictionary] = []

func _init(
	new_combatant_id: String = "",
	new_profile_path: String = "",
	profile: Resource = null
) -> void:
	if profile != null:
		configure_from_profile(new_combatant_id, new_profile_path, profile)
	else:
		combatant_id = new_combatant_id
		profile_path = new_profile_path
		_reset_default_stats()
		recalculate_max_hp(true)

## Copies authored identity and base stats into this persistent combatant state.
func configure_from_profile(new_combatant_id: String, new_profile_path: String, profile: Resource) -> void:
	combatant_id = new_combatant_id.strip_edges()
	profile_path = new_profile_path.strip_edges()
	display_name = _profile_string(profile, "display_name", display_name)
	stats = _profile_stats(profile, 5)
	statuses.clear()
	runtime_modifiers.clear()
	recalculate_max_hp(true)

## Replaces runtime stat modifiers with a copied list owned by the current run.
func set_runtime_modifiers(modifiers: Array[Dictionary]) -> void:
	runtime_modifiers = modifiers.duplicate(true)

## Returns effective stats after runtime modifiers.
func get_effective_stats() -> Dictionary:
	var effective_stats: Dictionary = {}
	for stat_id: String in StatId.ALL:
		effective_stats[stat_id] = get_effective_stat(stat_id)
	return effective_stats

## Returns one effective stat after applying active runtime modifiers.
func get_effective_stat(stat_id: String) -> int:
	var resolved_stat_id: String = StatId.from_value(stat_id)
	var value: int = int(stats.get(resolved_stat_id, 0))
	for modifier in runtime_modifiers:
		if str(modifier.get("stat_id", "")) == resolved_stat_id:
			value += int(modifier.get("amount", 0))

	return max(value, 0)

## Recalculates maximum HP from effective vitality and optionally heals to full.
func recalculate_max_hp(heal_to_full: bool) -> void:
	set_max_hp(maxi(get_effective_stat(StatId.VIT), 1) * 10, heal_to_full)

## Updates max HP while preserving or restoring current HP according to the caller's intent.
func set_max_hp(new_max_hp: int, heal_to_full: bool = false) -> void:
	max_hp = max(new_max_hp, 1)
	if heal_to_full:
		current_hp = max_hp
	else:
		current_hp = clamp(current_hp, 0, max_hp)
	is_alive = current_hp > 0

## Updates current HP and living state.
func set_current_hp(new_current_hp: int) -> void:
	current_hp = clamp(new_current_hp, 0, max(max_hp, 1))
	is_alive = current_hp > 0

## Copies this state into the current node-based combatant bridge.
func apply_stats_to_combatant(combatant: Variant) -> void:
	if combatant == null:
		return

	for stat_id: String in StatId.ALL:
		var field_name := str(StatId.PROFILE_FIELD_BY_ID.get(stat_id, ""))
		if not field_name.is_empty():
			combatant.set(field_name, get_effective_stat(stat_id))

func _reset_default_stats() -> void:
	stats = {}
	for stat_id: String in StatId.ALL:
		stats[stat_id] = 5

func _profile_stats(profile: Resource, default_value: int) -> Dictionary:
	var profile_stats: Dictionary = {}
	for stat_id: String in StatId.ALL:
		var field_name := str(StatId.PROFILE_FIELD_BY_ID.get(stat_id, ""))
		profile_stats[stat_id] = ValueReaderScript.resource_int(profile, field_name, default_value)
	return profile_stats

func _profile_string(profile: Resource, field_name: String, default_value: String) -> String:
	if profile == null:
		return default_value

	var value: Variant = profile.get(field_name)
	if value is String or value is StringName:
		var text: String = str(value)
		if not text.is_empty():
			return text

	return default_value
