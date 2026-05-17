## Stores persistent runtime combat data for any character or enemy that can participate in combat.
class_name CombatantState
extends RefCounted

const STAT_STRENGTH := "STR"
const STAT_DEXTERITY := "DEX"
const STAT_INTELLIGENCE := "INT"
const STAT_VITALITY := "VIT"
const STAT_FIELD_BY_ID := {
	STAT_STRENGTH: "strength",
	STAT_DEXTERITY: "dexterity",
	STAT_INTELLIGENCE: "intelligence",
	STAT_VITALITY: "vitality",
}
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
	stats = {
		STAT_STRENGTH: ValueReaderScript.resource_int(profile, "strength", 5),
		STAT_DEXTERITY: ValueReaderScript.resource_int(profile, "dexterity", 5),
		STAT_INTELLIGENCE: ValueReaderScript.resource_int(profile, "intelligence", 5),
		STAT_VITALITY: ValueReaderScript.resource_int(profile, "vitality", 5),
	}
	statuses.clear()
	runtime_modifiers.clear()
	recalculate_max_hp(true)

## Replaces runtime stat modifiers with a copied list owned by the current run.
func set_runtime_modifiers(modifiers: Array[Dictionary]) -> void:
	runtime_modifiers = modifiers.duplicate(true)

## Returns effective stats after runtime modifiers.
func get_effective_stats() -> Dictionary:
	return {
		STAT_STRENGTH: get_effective_stat(STAT_STRENGTH),
		STAT_DEXTERITY: get_effective_stat(STAT_DEXTERITY),
		STAT_INTELLIGENCE: get_effective_stat(STAT_INTELLIGENCE),
		STAT_VITALITY: get_effective_stat(STAT_VITALITY),
	}

## Returns one effective stat after applying active runtime modifiers.
func get_effective_stat(stat_id: String) -> int:
	var resolved_stat_id: String = canonical_stat_id(stat_id)
	var value := int(stats.get(resolved_stat_id, 0))
	for modifier in runtime_modifiers:
		if str(modifier.get("stat_id", "")) == resolved_stat_id:
			value += int(modifier.get("amount", 0))

	return max(value, 0)

## Recalculates maximum HP from effective vitality and optionally heals to full.
func recalculate_max_hp(heal_to_full: bool) -> void:
	set_max_hp(maxi(get_effective_stat(STAT_VITALITY), 1) * 10, heal_to_full)

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

	combatant.strength = get_effective_stat(STAT_STRENGTH)
	combatant.dexterity = get_effective_stat(STAT_DEXTERITY)
	combatant.intelligence = get_effective_stat(STAT_INTELLIGENCE)
	combatant.vitality = get_effective_stat(STAT_VITALITY)

static func canonical_stat_id(stat_id: String) -> String:
	var normalized := stat_id.strip_edges().to_upper()
	if STAT_FIELD_BY_ID.has(normalized):
		return normalized

	match normalized:
		"STRENGTH":
			return STAT_STRENGTH
		"DEXTERITY":
			return STAT_DEXTERITY
		"INTELLIGENCE":
			return STAT_INTELLIGENCE
		"VITALITY":
			return STAT_VITALITY
		_:
			return STAT_STRENGTH

func _reset_default_stats() -> void:
	stats = {
		STAT_STRENGTH: 5,
		STAT_DEXTERITY: 5,
		STAT_INTELLIGENCE: 5,
		STAT_VITALITY: 5,
	}

func _profile_string(profile: Resource, field_name: String, default_value: String) -> String:
	if profile == null:
		return default_value

	var value: Variant = profile.get(field_name)
	if value is String or value is StringName:
		var text := str(value)
		if not text.is_empty():
			return text

	return default_value
