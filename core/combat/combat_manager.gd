## Autoload manager for combat payload validation, active combat context, and pending combat results.
extends Node

const CombatResultScript := preload("res://core/combat/combat_result.gd")
const CombatPayloadValidatorScript := preload("res://core/combat/combat_payload_validator.gd")
const RewardServiceScript := preload("res://core/rewards/reward_service.gd")

var _current_combat_payload: Dictionary = {}
var _pending_combat_result: Variant = null
var _current_run_data: Variant = null
var _has_active_combat: bool = false
var _cached_reward_profiles: Array[Resource] = []

func start_combat_from_dungeon(run_data: Variant, node_id: int, encounter_payload: Dictionary) -> void:
	if run_data == null:
		push_error("CombatManager cannot start dungeon combat without run data.")
		return

	var payload := encounter_payload.duplicate(true)
	payload["node_id"] = node_id
	validate_combat_payload(payload)
	if payload.is_empty() or not CombatPayloadValidatorScript.is_valid_combat_payload(payload):
		return

	_current_combat_payload = payload
	_cached_reward_profiles = _reward_profiles_for_instances(payload.get("enemy_instances", []))
	_pending_combat_result = null
	_current_run_data = run_data
	_has_active_combat = true

func get_current_combat_payload() -> Dictionary:
	return _current_combat_payload.duplicate(true)

func validate_combat_payload(payload: Dictionary) -> void:
	var payload_error := CombatPayloadValidatorScript.combat_payload_error(payload)
	if not payload_error.is_empty():
		push_error("Invalid combat payload (%s): %s." % [payload_error, payload])

func complete_combat(result: Variant) -> void:
	if result == null:
		push_error("CombatManager cannot complete combat with a null result.")
		return
	if not _required_services_available():
		push_error("CombatManager cannot complete combat because required manager autoloads are unavailable.")
		return

	_apply_combat_result_to_run(_current_run_data, result)
	_pending_combat_result = result
	_has_active_combat = false

func consume_pending_combat_result() -> Variant:
	var result: Variant = _pending_combat_result
	_pending_combat_result = null
	return result

func has_pending_combat_result() -> bool:
	return _pending_combat_result != null

func has_active_combat() -> bool:
	return _has_active_combat

func get_combat_snapshot() -> Dictionary:
	return {
		"has_active_combat": _has_active_combat,
		"has_pending_result": _pending_combat_result != null,
		"payload": _current_combat_payload.duplicate(true),
	}

func _apply_combat_result_to_run(run_data: Variant, result: Variant) -> void:
	if run_data == null or result == null:
		return

	run_data.damage_dealt += max(int(result.damage_dealt), 0)
	run_data.damage_taken += max(int(result.damage_taken), 0)
	run_data.actions_used += max(int(result.actions_used), 0)
	_apply_combat_participant_results(run_data, result.get("participant_results"))

	if not bool(result.victory):
		var end_reason := str(result.end_reason)
		run_data.end_run(end_reason if not end_reason.is_empty() else RunData.END_REASON_DEFEAT)
		return

	var reward_package: Dictionary = _combat_reward_package_for_result(result)
	var dungeon_manager: Variant = _dungeon_manager()
	result.reward_package = reward_package
	RewardServiceScript.apply_reward_package_to_run(run_data, reward_package)
	run_data.fights_completed += 1
	dungeon_manager.resolve_node(run_data, int(result.node_id))

	if bool(result.is_boss):
		run_data.boss_defeated = true
		run_data.end_run(RunData.END_REASON_VICTORY)
	else:
		run_data.regular_fights_completed += 1

func _apply_combat_participant_results(run_data: Variant, raw_participant_results: Variant) -> void:
	if run_data == null or not (raw_participant_results is Array):
		return

	for raw_result in raw_participant_results:
		if raw_result is Dictionary:
			_apply_player_participant_result(run_data, raw_result)

func _apply_player_participant_result(run_data: Variant, participant_result: Dictionary) -> void:
	if str(participant_result.get(CombatResultScript.PARTICIPANT_SIDE_ID, "")) != CombatResultScript.SIDE_ID_PLAYER:
		return
	if run_data.player_party_state == null:
		return

	var combatant_id := str(participant_result.get(CombatResultScript.PARTICIPANT_COMBATANT_ID, "")).strip_edges()
	if combatant_id.is_empty():
		return

	var member: Variant = run_data.player_party_state.get_member_for_combatant_id(combatant_id)
	if member == null or member.combatant_state == null:
		return

	var combatant_state: Variant = member.combatant_state
	var max_hp_value := int(participant_result.get(CombatResultScript.PARTICIPANT_MAX_HP, combatant_state.max_hp))
	var hp_after_value := int(participant_result.get(CombatResultScript.PARTICIPANT_HP_AFTER, combatant_state.current_hp))
	if max_hp_value > 0:
		combatant_state.set_max_hp(max_hp_value, false)
	combatant_state.set_current_hp(hp_after_value)

func _required_services_available() -> bool:
	return _dungeon_manager() != null

func _dungeon_manager() -> Variant:
	return get_node_or_null("/root/DungeonManager")

func _combat_reward_package_for_result(result: Variant) -> Dictionary:
	var enemy_instances: Array = _current_combat_payload.get("enemy_instances", [])
	return RewardServiceScript.calculate_combat_reward_package(
		enemy_instances,
		_cached_reward_profiles,
		bool(result.is_boss),
		StringName(str(result.node_id))
	)

func _reward_profiles_for_instances(enemy_instances: Array) -> Array[Resource]:
	var profiles: Array[Resource] = []
	for raw_instance in enemy_instances:
		if not (raw_instance is Dictionary):
			continue
		var instance: Dictionary = raw_instance
		var profile_path: String = str(instance.get("profile_path", "")).strip_edges()
		if profile_path.is_empty():
			continue
		var profile: Resource = load(profile_path) as Resource
		if profile == null:
			push_error("CombatManager could not load reward profile source: %s." % profile_path)
			continue
		profiles.append(profile)
	return profiles
