## Autoload manager for party setup, selected character lookup, member state access, and party reward application.
extends Node

const PlayerRunStateServiceScript := preload("res://core/party/player_run_state_service.gd")
const PlayerPartyStateScript := preload("res://core/party/player_party_state.gd")

const CHARACTER_PROFILE_PATHS := {
	"Warrior": "res://scenes/combatants/characters/warrior/warrior_profile.tres",
}

#; Current multiplayer assumption: one local player owns one selected party member; REMOTE_PLAYER remains reserved only.
func initialize_party_for_run(run_data: Variant, character_id: StringName) -> void:
	if run_data == null:
		push_error("PartyManager cannot initialize a party without run data.")
		return

	var resolved_character_id := String(character_id)
	var profile := get_character_profile(resolved_character_id)
	var profile_path := get_character_profile_path(resolved_character_id)
	if profile == null or profile_path.is_empty():
		return

	if run_data.has_method("configure_selection"):
		run_data.configure_selection(resolved_character_id)
	run_data.player_party_state = PlayerPartyStateScript.new()
	run_data.player_party_state.configure_single_member(resolved_character_id, profile_path, profile)
	PlayerRunStateServiceScript.sync_modifiers(run_data)

func get_selected_character_id(run_data: Variant) -> StringName:
	if run_data != null:
		return StringName(str(run_data.get("selected_character")))

	return StringName(RunData.DEFAULT_CHARACTER)

func get_selected_character_profile(run_data: Variant) -> Resource:
	return get_character_profile(String(get_selected_character_id(run_data)))

func get_character_profile(character_id: String) -> Resource:
	var profile_path := get_character_profile_path(character_id)
	if profile_path.is_empty():
		return null

	var profile := load(profile_path) as Resource
	if profile == null:
		push_error("Character profile %s could not be loaded from %s." % [character_id, profile_path])
	return profile

func get_character_profile_path(character_id: String) -> String:
	var resolved_id := character_id.strip_edges()
	if resolved_id.is_empty():
		resolved_id = RunData.DEFAULT_CHARACTER
	if not CHARACTER_PROFILE_PATHS.has(resolved_id):
		push_error("Unknown character id: %s." % resolved_id)
		return ""

	return str(CHARACTER_PROFILE_PATHS[resolved_id])

func get_selected_member_state(run_data: Variant) -> Variant:
	if run_data == null or run_data.player_party_state == null:
		return null

	return run_data.player_party_state.get_selected_member()

func get_selected_combatant_id(run_data: Variant) -> String:
	var member: Variant = get_selected_member_state(run_data)
	if member == null or member.combatant_state == null:
		return ""

	return str(member.combatant_state.combatant_id)

func apply_member_state_to_combatant(run_data: Variant, combatant: Node, party_member_id: StringName = &"") -> void:
	if run_data == null or combatant == null:
		return

	var member: Variant = null
	if run_data.player_party_state != null and not String(party_member_id).is_empty():
		member = run_data.player_party_state.get_member(String(party_member_id))
	else:
		member = get_selected_member_state(run_data)
	if member != null and member.combatant_state != null:
		combatant.set("combatant_id", str(member.combatant_state.combatant_id))

	PlayerRunStateServiceScript.apply_run_state_to_combatant(run_data, combatant)

func get_selected_member_hp_snapshot(run_data: Variant) -> Dictionary:
	return PlayerRunStateServiceScript.hp_snapshot(run_data)

func get_selected_member_effective_stats(run_data: Variant) -> Dictionary:
	return PlayerRunStateServiceScript.effective_player_stats(run_data, get_selected_character_profile(run_data))

func advance_run_effects(run_data: Variant, seconds: float) -> void:
	PlayerRunStateServiceScript.tick_modifiers(run_data, seconds)

func resolve_encounter_choice_effects(run_data: Variant, choice_data: Dictionary) -> Dictionary:
	var outcome := {
		"damage_taken": 0,
		"stat_modifiers_added": 0,
	}
	if choice_data.is_empty():
		return outcome

	var effects_value: Variant = choice_data.get("effects", [])
	if not (effects_value is Array):
		return outcome

	for effect in effects_value:
		if not (effect is Dictionary):
			continue
		var effect_result: Dictionary = _resolve_encounter_effect(run_data, effect)
		outcome["damage_taken"] = int(outcome["damage_taken"]) + int(effect_result.get("damage_taken", 0))
		outcome["stat_modifiers_added"] = int(outcome["stat_modifiers_added"]) + int(effect_result.get("stat_modifiers_added", 0))

	return outcome

func _resolve_encounter_effect(run_data: Variant, effect_data: Dictionary) -> Dictionary:
	var outcome := {
		"damage_taken": 0,
		"stat_modifiers_added": 0,
	}
	if run_data == null or effect_data.is_empty():
		return outcome

	var effect_id: StringName = _effect_id(effect_data)
	var amount: int = int(effect_data.get("amount", 0))
	match effect_id:
		&"damage":
			var actual_damage: int = PlayerRunStateServiceScript.apply_damage(run_data, amount)
			run_data.damage_taken += actual_damage
			outcome["damage_taken"] = actual_damage
		&"stat":
			if PlayerRunStateServiceScript.add_stat_modifier(
				run_data,
				str(effect_data.get("stat", StatId.STR)),
				amount,
				bool(effect_data.get("permanent", false)),
				float(effect_data.get("duration", 0.0))
			):
				outcome["stat_modifiers_added"] = 1

	return outcome

func is_player_defeated(run_data: Variant) -> bool:
	return PlayerRunStateServiceScript.is_player_defeated(run_data)

func get_party_snapshot(run_data: Variant) -> Dictionary:
	var member: Variant = get_selected_member_state(run_data)
	return {
		"selected_character_id": String(get_selected_character_id(run_data)),
		"selected_member_id": str(member.party_member_id) if member != null else "",
		"hp": get_selected_member_hp_snapshot(run_data),
		"effective_stats": get_selected_member_effective_stats(run_data),
	}

func _effect_id(effect_data: Dictionary) -> StringName:
	var value: Variant = effect_data.get("id", &"")
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return &""
