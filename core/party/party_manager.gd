## Autoload manager for party setup, selected character lookup, member state access, and party reward application.
extends Node

const PlayerRunStateServiceScript := preload("res://core/party/player_run_state_service.gd")
const PlayerPartyStateScript := preload("res://core/party/player_party_state.gd")
const ClassRunStateScript := preload("res://core/combat/classes/class_run_state.gd")
const ClassProfileDataScript := preload("res://core/combat/classes/class_profile_data.gd")

const CHARACTER_PROFILE_PATHS := {
	"Warrior": "res://scenes/combatants/characters/warrior/warrior_profile.tres",
}

func default_character_id() -> String:
	return RunData.DEFAULT_CHARACTER

func character_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in CHARACTER_PROFILE_PATHS.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids

func has_character(character_id: String) -> bool:
	return CHARACTER_PROFILE_PATHS.has(character_id.strip_edges())

func get_character_display_name(character_id: String) -> String:
	var profile := get_character_profile(character_id)
	if profile != null:
		var display_name := str(profile.get("display_name")).strip_edges()
		if not display_name.is_empty():
			return display_name
	return character_id.strip_edges()

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
	ensure_member_class_run_states(run_data)
	PlayerRunStateServiceScript.sync_modifiers(run_data)

func initialize_party_for_multiplayer_run(run_data: Variant, member_configs: Array[Dictionary], local_peer_id: int) -> void:
	if run_data == null:
		push_error("PartyManager cannot initialize a multiplayer party without run data.")
		return
	if member_configs.is_empty():
		push_error("PartyManager cannot initialize a multiplayer party without member configs.")
		return

	run_data.player_party_state = PlayerPartyStateScript.new()
	run_data.player_party_state.configure_members(member_configs, local_peer_id)
	var leader: Variant = run_data.player_party_state.get_leader()
	if leader != null and run_data.has_method("configure_selection"):
		run_data.configure_selection(str(leader.character_id))
	ensure_member_class_run_states(run_data)
	PlayerRunStateServiceScript.sync_modifiers(run_data)

func build_member_configs_from_network_players(players_snapshot: Dictionary) -> Array[Dictionary]:
	var member_configs: Array[Dictionary] = []
	var peer_ids: Array[int] = []
	for raw_peer_id in players_snapshot.keys():
		peer_ids.append(int(raw_peer_id))
	peer_ids.sort()

	for peer_id in peer_ids:
		var player_info: Dictionary = players_snapshot.get(str(peer_id), {})
		if player_info.is_empty():
			player_info = players_snapshot.get(peer_id, {})
		if player_info.is_empty():
			continue
		var character_id := str(player_info.get("selected_character_id", RunData.DEFAULT_CHARACTER)).strip_edges()
		if character_id.is_empty():
			character_id = RunData.DEFAULT_CHARACTER
		var profile_path := get_character_profile_path(character_id)
		if profile_path.is_empty():
			push_error("Cannot build party member config for unknown character %s." % character_id)
			continue
		var normalized_character := _normalized_id(character_id)
		member_configs.append({
			"party_member_id": "party_member.peer_%s.%s" % [peer_id, normalized_character],
			"character_id": character_id,
			"combatant_id": "combatant.peer_%s.%s" % [peer_id, normalized_character],
			"profile_path": profile_path,
			"owner_peer_id": peer_id,
			"platform_user_id": str(player_info.get("platform_user_id", "")),
			"is_active": true,
		})

	if member_configs.is_empty():
		push_error("Network players did not produce any valid party member configs.")
	return member_configs

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
		push_error("Character id cannot be empty.")
		return ""
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

	ensure_member_class_run_states(run_data)
	var member: Variant = null
	if run_data.player_party_state != null and not String(party_member_id).is_empty():
		member = run_data.player_party_state.get_member(String(party_member_id))
	else:
		member = get_selected_member_state(run_data)
	if member != null and member.combatant_state != null:
		combatant.set("combatant_id", str(member.combatant_state.combatant_id))
		member.combatant_state.set_runtime_modifiers(run_data.run_stat_modifiers)
		member.combatant_state.apply_stats_to_combatant(combatant)
		if member.class_run_state != null and combatant.has_method("set_class_run_state"):
			combatant.call("set_class_run_state", member.class_run_state)
	else:
		PlayerRunStateServiceScript.apply_run_state_to_combatant(run_data, combatant)

func ensure_member_class_run_states(run_data: Variant) -> void:
	if run_data == null or run_data.player_party_state == null:
		return

	for raw_member in run_data.player_party_state.members.values():
		var member: Variant = raw_member
		if member == null or member.combatant_state == null:
			continue
		if member.class_run_state != null and member.class_profile != null:
			continue
		var profile := _profile_for_member(member)
		var class_profile := _class_profile_for_combatant_profile(profile)
		if class_profile == null:
			continue
		member.class_profile = class_profile
		if member.class_run_state == null:
			member.class_run_state = ClassRunStateScript.new()
		if member.class_run_state.has_method("configure_defaults"):
			member.class_run_state.configure_defaults(class_profile)

func get_selected_member_class_run_state(run_data: Variant) -> Variant:
	ensure_member_class_run_states(run_data)
	var member: Variant = get_selected_member_state(run_data)
	return member.class_run_state if member != null else null

func get_member_class_run_state(run_data: Variant, party_member_id: String) -> Variant:
	ensure_member_class_run_states(run_data)
	if run_data == null or run_data.player_party_state == null:
		return null
	var member: Variant = run_data.player_party_state.get_member(party_member_id)
	return member.class_run_state if member != null else null

func get_selected_member_class_profile(run_data: Variant) -> Resource:
	ensure_member_class_run_states(run_data)
	var member: Variant = get_selected_member_state(run_data)
	return member.class_profile if member != null else null

func get_class_run_state_for_combatant_id(run_data: Variant, combatant_id: String) -> Variant:
	ensure_member_class_run_states(run_data)
	if run_data == null or run_data.player_party_state == null:
		return null
	var member: Variant = run_data.player_party_state.get_member_for_combatant_id(combatant_id)
	return member.class_run_state if member != null else null

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
		"active_member_ids": _active_member_ids_snapshot(run_data),
		"members": _member_snapshots(run_data),
	}

func _effect_id(effect_data: Dictionary) -> StringName:
	var value: Variant = effect_data.get("id", &"")
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return &""

func _member_snapshots(run_data: Variant) -> Dictionary:
	var snapshots: Dictionary = {}
	if run_data == null or run_data.player_party_state == null:
		return snapshots

	ensure_member_class_run_states(run_data)
	PlayerRunStateServiceScript.sync_modifiers(run_data)
	for member_id: String in run_data.player_party_state.active_member_ids:
		var member: Variant = run_data.player_party_state.get_member(member_id)
		if member == null or member.combatant_state == null:
			continue
		var combatant_state: Variant = member.combatant_state
		snapshots[member_id] = {
			"party_member_id": str(member.party_member_id),
			"character_id": str(member.character_id),
			"combatant_id": str(combatant_state.combatant_id),
			"profile_path": str(combatant_state.profile_path),
			"owner_peer_id": int(member.owner_peer_id),
			"platform_user_id": str(member.platform_user_id),
			"control_mode": str(member.control_mode_id()),
			"map_pawn_id": str(member.map_pawn_id),
			"is_unlocked": bool(member.is_unlocked),
			"is_active": bool(member.is_active),
			"hp": {
				"current": int(combatant_state.current_hp),
				"max": int(combatant_state.max_hp),
			},
			"effective_stats": combatant_state.get_effective_stats(),
			"class_state": _class_state_snapshot(member),
		}
	return snapshots

func _active_member_ids_snapshot(run_data: Variant) -> Array[String]:
	if run_data == null or run_data.player_party_state == null:
		return []
	return run_data.player_party_state.active_member_ids.duplicate()

func _normalized_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "_")
	if normalized.is_empty():
		return "member"
	return normalized

func _profile_for_member(member: Variant) -> Resource:
	if member == null or member.combatant_state == null:
		return null
	var profile_path := str(member.combatant_state.profile_path).strip_edges()
	if profile_path.is_empty():
		return null
	var profile := load(profile_path) as Resource
	if profile == null:
		push_error("Could not load party member profile %s for class state." % profile_path)
	return profile

func _class_profile_for_combatant_profile(profile: Resource) -> Resource:
	if profile == null:
		return null
	var class_profile: Resource = profile.get("class_profile") as Resource
	if class_profile == null:
		return null
	if class_profile.get_script() == ClassProfileDataScript:
		var validation_error: String = str(class_profile.validate())
		if not validation_error.is_empty():
			push_error(validation_error)
			return null
		return class_profile
	push_error("Unsupported class profile type for %s." % profile.resource_path)
	return null

func _class_state_snapshot(member: Variant) -> Dictionary:
	if member == null or member.class_run_state == null:
		return {}
	if member.class_run_state.has_method("to_snapshot"):
		return member.class_run_state.to_snapshot()
	return {}
