## Stores all mutable state for a run, including selection, timer, encounters, rewards, and combat totals.
class_name RunData
extends RefCounted

const DungeonMapPawnStateScript := preload("res://core/dungeon/dungeon_map_pawn_state.gd")
const DungeonPathfinderScript := preload("res://core/dungeon/dungeon_pathfinder.gd")
const CombatResultScript := preload("res://core/combat/combat_result.gd")
const StatId := preload("res://core/combat/stat_id.gd")
const PartyControlModeScript := preload("res://core/party/party_control_mode.gd")
const PlayerPartyStateScript := preload("res://core/party/player_party_state.gd")
const PlayerRunStateServiceScript := preload("res://core/party/player_run_state_service.gd")

const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"
const DEFAULT_CHARACTER := "Warrior"
const DEFAULT_DIFFICULTY := "normal"
const DEFAULT_RUN_TIME_SECONDS := 1000.0
const START_DUNGEON_NODE_ID := 0
const LOCAL_OWNER_PLAYER_ID := "local"
const NODE_TRAVEL_TIME := 1.0
const VISUAL_NODE_STEPS_PER_REAL_SECOND := 4.0
const ALLOW_DESTINATION_REPLACE_DURING_TRAVEL := true
const ALLOW_CANCEL_AFTER_CURRENT_STEP := true
const TRAVEL_RESULT_AUTOPILOT_FOLLOW_RESULTS := "autopilot_follow_results"

var selected_character: String = DEFAULT_CHARACTER
var selected_difficulty: String = DEFAULT_DIFFICULTY
var dungeon_seed: String = ""
var dungeon_floor_layer: int = 1
var dungeon_node_descriptors: Array = []
var dungeon_map_pawns: Dictionary = {}
var active_dungeon_pawn_ids: Array[String] = []
var revealed_dungeon_node_ids: Array[int] = []
var resolved_dungeon_node_ids: Array[int] = []

var max_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var remaining_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var gold: int = 0
var memories: int = 0
var run_end_reason: String = END_REASON_IN_PROGRESS
var memories_exported: bool = false
var player_party_state = null
var run_stat_modifiers: Array[Dictionary] = []

var current_node_index: int = 0
var current_dungeon_node_id: int = -1
var total_nodes: int = 5
var boss_node_index: int = 4
var visited_dungeon_node_ids: Array[int] = []

var fights_completed: int = 0
var regular_fights_completed: int = 0
var boss_defeated: bool = false

var damage_dealt: int = 0
var damage_taken: int = 0
var actions_used: int = 0
var time_elapsed: float = 0.0

var run_victory: bool = false
var pending_combat_result = null
var current_encounter_node_id: int = -1
var current_encounter_node_type: String = ""
var current_encounter_enemy_profile_path: String = ""
var current_encounter_enemy_instances: Array[Dictionary] = []
var current_encounter_combat_id: StringName = &""
var current_encounter_combat_profile_path: String = ""
var current_encounter_is_boss: bool = false

func configure_selection(character: String, difficulty: String) -> void:
	selected_character = character if not character.is_empty() else DEFAULT_CHARACTER
	selected_difficulty = difficulty if not difficulty.is_empty() else DEFAULT_DIFFICULTY

func start_run(
	character: String,
	difficulty: String,
	run_time_seconds: float,
	default_enemy_profile_path: String,
	new_dungeon_seed: String = "",
	new_dungeon_floor_layer: int = 1
) -> void:
	configure_selection(character, difficulty)
	dungeon_seed = new_dungeon_seed.strip_edges()
	dungeon_floor_layer = max(new_dungeon_floor_layer, 1)
	dungeon_node_descriptors.clear()
	dungeon_map_pawns.clear()
	active_dungeon_pawn_ids.clear()
	revealed_dungeon_node_ids.clear()
	resolved_dungeon_node_ids.clear()
	gold = 0
	memories = 0
	run_end_reason = END_REASON_IN_PROGRESS
	memories_exported = false
	player_party_state = null
	run_stat_modifiers.clear()
	pending_combat_result = null
	current_node_index = 0
	current_dungeon_node_id = -1
	total_nodes = 5
	boss_node_index = 4
	visited_dungeon_node_ids.clear()
	fights_completed = 0
	regular_fights_completed = 0
	boss_defeated = false
	damage_dealt = 0
	damage_taken = 0
	actions_used = 0
	run_victory = false
	reset_encounter(default_enemy_profile_path)
	reset_run_timer(run_time_seconds)

func reset_run_timer(new_max_run_time_seconds: float) -> void:
	max_run_time_seconds = max(new_max_run_time_seconds, 1.0)
	remaining_run_time_seconds = max_run_time_seconds
	time_elapsed = 0.0

func advance_time(seconds: float) -> float:
	if seconds <= 0.0 or run_end_reason != END_REASON_IN_PROGRESS:
		return 0.0

	var applied_seconds: float = min(seconds, remaining_run_time_seconds)
	remaining_run_time_seconds = max(remaining_run_time_seconds - applied_seconds, 0.0)
	time_elapsed += applied_seconds
	_tick_run_stat_modifiers(applied_seconds)
	return applied_seconds

func grant_rewards(new_memories: int, new_gold: int) -> void:
	memories += max(new_memories, 0)
	gold += max(new_gold, 0)

func end_run(reason: String) -> void:
	if reason.is_empty():
		reason = END_REASON_DEFEAT

	run_end_reason = reason
	run_victory = reason == END_REASON_VICTORY

func has_ended() -> bool:
	return run_end_reason != END_REASON_IN_PROGRESS

func reset_encounter(default_enemy_profile_path: String) -> void:
	current_encounter_node_id = -1
	current_encounter_node_type = ""
	current_encounter_enemy_profile_path = default_enemy_profile_path
	current_encounter_enemy_instances.clear()
	current_encounter_combat_id = &""
	current_encounter_combat_profile_path = ""
	current_encounter_is_boss = false

func initialize_player_state(profile: Resource, profile_path: String = "") -> void:
	player_party_state = PlayerPartyStateScript.new()
	player_party_state.configure_single_member(selected_character, profile_path, profile)
	_sync_player_state_modifiers()

func get_effective_stats() -> Dictionary:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state != null:
		_sync_player_state_modifiers()
		return combatant_state.get_effective_stats()

	var effective_stats: Dictionary = {}
	for stat_id in StatId.ALL:
		effective_stats[stat_id] = 0
	return effective_stats

func get_effective_stat(stat_id: String) -> int:
	var resolved_stat_id := StatId.from_value(stat_id)
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state != null:
		_sync_player_state_modifiers()
		return combatant_state.get_effective_stat(resolved_stat_id)

	return 0

func apply_player_stats_to_combatant(combatant: Variant) -> void:
	if combatant == null:
		return

	var combatant_state: Variant = _player_combatant_state()
	if combatant_state != null:
		_sync_player_state_modifiers()
		combatant_state.apply_stats_to_combatant(combatant)
		return

	for stat_id in StatId.ALL:
		var field_name := str(StatId.PROFILE_FIELD_BY_ID.get(stat_id, ""))
		if not field_name.is_empty():
			combatant.set(field_name, get_effective_stat(stat_id))

func get_player_hp_snapshot() -> Dictionary:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state != null:
		return {
			"current": int(combatant_state.current_hp),
			"max": int(combatant_state.max_hp),
		}

	return {
		"current": 0,
		"max": 0,
	}

func get_selected_player_combatant_id() -> String:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return ""

	return str(combatant_state.combatant_id)

func set_player_hp(current_hp: int, max_hp: int = -1) -> void:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return

	if max_hp > 0:
		combatant_state.set_max_hp(max_hp, false)
	combatant_state.set_current_hp(current_hp)

func apply_encounter_choice(choice_data: Dictionary) -> Dictionary:
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
		var effect_result := apply_encounter_effect(effect)
		outcome["damage_taken"] = int(outcome["damage_taken"]) + int(effect_result.get("damage_taken", 0))
		outcome["stat_modifiers_added"] = int(outcome["stat_modifiers_added"]) + int(effect_result.get("stat_modifiers_added", 0))

	return outcome

func apply_encounter_effect(effect_data: Dictionary) -> Dictionary:
	var outcome := {
		"damage_taken": 0,
		"stat_modifiers_added": 0,
	}
	if effect_data.is_empty():
		return outcome

	var effect_id := _effect_id(effect_data)
	var amount := int(effect_data.get("amount", 0))
	match effect_id:
		&"damage":
			var hp_snapshot := get_player_hp_snapshot()
			var previous_hp := int(hp_snapshot.get("current", 0))
			set_player_hp(previous_hp - max(amount, 0), int(hp_snapshot.get("max", 0)))
			var actual_damage := previous_hp - int(get_player_hp_snapshot().get("current", 0))
			damage_taken += actual_damage
			outcome["damage_taken"] = actual_damage
		&"stat":
			if amount == 0:
				return outcome
			var permanent := bool(effect_data.get("permanent", false))
			var duration_seconds := float(effect_data.get("duration", 0.0))
			if not permanent and duration_seconds <= 0.0:
				return outcome
			run_stat_modifiers.append({
				"stat_id": StatId.from_value(effect_data.get("stat", StatId.STR)),
				"amount": amount,
				"permanent": permanent,
				"remaining_seconds": duration_seconds,
			})
			_sync_player_state_modifiers()
			_recalculate_player_max_hp(false)
			outcome["stat_modifiers_added"] = 1

	return outcome

func is_player_defeated() -> bool:
	return int(get_player_hp_snapshot().get("current", 0)) <= 0

func set_encounter(
	node_id: int,
	node_type: String,
	enemy_profile_path: String,
	is_boss: bool,
	default_enemy_profile_path: String,
	combat_encounter_id: StringName = &"",
	combat_encounter_profile_path: String = "",
	enemy_instances: Array[Dictionary] = []
) -> void:
	current_encounter_node_id = node_id
	current_encounter_node_type = node_type
	current_encounter_enemy_profile_path = enemy_profile_path if not enemy_profile_path.is_empty() else default_enemy_profile_path
	current_encounter_enemy_instances = enemy_instances.duplicate(true)
	current_encounter_combat_id = combat_encounter_id
	current_encounter_combat_profile_path = combat_encounter_profile_path.strip_edges()
	current_encounter_is_boss = is_boss
	pending_combat_result = null

func get_current_encounter(default_enemy_profile_path: String) -> Dictionary:
	return {
		"node_id": current_encounter_node_id,
		"node_type": current_encounter_node_type,
		"enemy_profile_path": current_encounter_enemy_profile_path if not current_encounter_enemy_profile_path.is_empty() else default_enemy_profile_path,
		"enemy_instances": current_encounter_enemy_instances.duplicate(true),
		"combat_encounter_id": current_encounter_combat_id,
		"combat_encounter_profile_path": current_encounter_combat_profile_path,
		"is_boss": current_encounter_is_boss,
	}

func store_combat_result(result: Variant) -> void:
	pending_combat_result = result

func has_pending_combat_result() -> bool:
	return pending_combat_result != null

func consume_pending_combat_result() -> Variant:
	var result = pending_combat_result
	pending_combat_result = null
	return result

## Creates active dungeon pawns and seeds the initial revealed/visited node state.
func initialize_dungeon_map_state(start_node_id: int = START_DUNGEON_NODE_ID) -> void:
	dungeon_map_pawns.clear()
	active_dungeon_pawn_ids.clear()
	revealed_dungeon_node_ids.clear()
	resolved_dungeon_node_ids.clear()
	visited_dungeon_node_ids.clear()
	current_node_index = 0
	current_dungeon_node_id = -1

	var active_members: Array = []
	if player_party_state != null:
		active_members = player_party_state.get_active_members()

	for member in active_members:
		if member == null or member.is_inactive():
			continue

		var pawn_id := _dungeon_pawn_id_for_member(str(member.party_member_id))
		var pawn: Variant = DungeonMapPawnStateScript.new()
		pawn.configure_for_party_member(pawn_id, member, start_node_id, LOCAL_OWNER_PLAYER_ID)
		dungeon_map_pawns[pawn_id] = pawn
		active_dungeon_pawn_ids.append(pawn_id)
		member.map_pawn_id = pawn_id

	mark_dungeon_node_visited(start_node_id)

func has_dungeon_map_pawns() -> bool:
	return not dungeon_map_pawns.is_empty()

func get_dungeon_map_pawn(pawn_id: String) -> Variant:
	return dungeon_map_pawns.get(pawn_id, null)

func get_selected_dungeon_map_pawn() -> Variant:
	if player_party_state != null:
		var member: Variant = player_party_state.get_selected_member()
		if member == null:
			member = player_party_state.get_leader()
		if member != null and not str(member.map_pawn_id).is_empty():
			var member_pawn: Variant = get_dungeon_map_pawn(str(member.map_pawn_id))
			if member_pawn != null:
				return member_pawn

	for pawn_id in active_dungeon_pawn_ids:
		var pawn: Variant = get_dungeon_map_pawn(pawn_id)
		if pawn != null:
			return pawn

	return null

func get_dungeon_map_pawn_for_party_member(party_member_id: String) -> Variant:
	if player_party_state != null:
		var member: Variant = player_party_state.get_member(party_member_id)
		if member != null and not str(member.map_pawn_id).is_empty():
			return get_dungeon_map_pawn(str(member.map_pawn_id))

	for pawn in dungeon_map_pawns.values():
		var map_pawn: Variant = pawn
		if map_pawn != null and map_pawn.party_member_id == party_member_id:
			return map_pawn

	return null

## Moves a pawn's map position without changing visited/resolved node state.
func move_dungeon_pawn_to_node(pawn_id: String, node_id: int) -> bool:
	var pawn: Variant = get_dungeon_map_pawn(pawn_id)
	if pawn == null or node_id < 0:
		return false

	pawn.set_current_node_id(node_id)
	current_node_index = max(current_node_index, node_id)
	if _is_selected_dungeon_pawn_id(str(pawn.pawn_id)):
		current_dungeon_node_id = node_id
	return true

func get_current_dungeon_node_id() -> int:
	var pawn: Variant = get_selected_dungeon_map_pawn()
	if pawn != null and pawn.current_node_id >= 0:
		return pawn.current_node_id

	return current_dungeon_node_id

## Records that a node was physically entered and syncs only the entering pawn when provided.
func mark_dungeon_node_visited(node_id: int, pawn_id: String = "") -> void:
	if node_id < 0:
		return

	_mark_dungeon_node_visit_state(node_id)
	var synced_pawn := _sync_current_pawn_node(node_id, pawn_id)
	if not synced_pawn and pawn_id.is_empty():
		current_dungeon_node_id = node_id

## Marks a node resolved while preserving the invariant: resolved nodes are visited and revealed.
func mark_dungeon_node_resolved(node_id: int) -> void:
	if node_id < 0:
		return

	_mark_dungeon_node_visit_state(node_id)
	_add_node_id(resolved_dungeon_node_ids, node_id)

## Resolves a node event/effect and unlocks only pawns participating in that event node.
func complete_dungeon_node(node_id: int, pawn_id: String = "") -> void:
	if node_id < 0:
		return

	var completion_pawn_ids := _completion_pawn_ids_for_node(node_id, pawn_id)
	if completion_pawn_ids.is_empty():
		if pawn_id.is_empty():
			mark_dungeon_node_visited(node_id)
		else:
			_mark_dungeon_node_visit_state(node_id)
	else:
		_mark_dungeon_node_visit_state(node_id)
		for completion_pawn_id in completion_pawn_ids:
			_sync_current_pawn_node(node_id, completion_pawn_id)
	mark_dungeon_node_resolved(node_id)
	unlock_dungeon_pawns_for_event_node(node_id)

## Returns pawn IDs currently locked as participants in the event at the provided node.
func get_event_locked_dungeon_pawn_ids(node_id: int) -> Array[String]:
	var locked_pawn_ids: Array[String] = []
	if node_id < 0:
		return locked_pawn_ids

	for raw_pawn in dungeon_map_pawns.values():
		var pawn: Variant = raw_pawn
		if _is_pawn_locked_for_event_node(pawn, node_id):
			_add_pawn_id(locked_pawn_ids, str(pawn.pawn_id))

	return locked_pawn_ids

## Unlocks any pawn whose active event was resolved at the provided node.
func unlock_dungeon_pawns_for_event_node(node_id: int) -> void:
	if node_id < 0:
		return

	for pawn_id in get_event_locked_dungeon_pawn_ids(node_id):
		var pawn: Variant = get_dungeon_map_pawn(pawn_id)
		if pawn == null:
			continue
		pawn.unlock_event()

func reveal_dungeon_node(node_id: int) -> void:
	_add_node_id(revealed_dungeon_node_ids, node_id)

func reveal_connected_dungeon_nodes(node_id: int) -> void:
	for connected_id in get_descriptor_connected_node_ids(node_id):
		reveal_dungeon_node(connected_id)

func is_dungeon_node_visited(node_id: int) -> bool:
	return visited_dungeon_node_ids.has(node_id)

func is_dungeon_node_revealed(node_id: int) -> bool:
	return revealed_dungeon_node_ids.has(node_id)

func is_dungeon_node_resolved(node_id: int) -> bool:
	return resolved_dungeon_node_ids.has(node_id)

func get_visited_dungeon_node_ids() -> Array[int]:
	return visited_dungeon_node_ids.duplicate()

func get_revealed_dungeon_node_ids() -> Array[int]:
	return revealed_dungeon_node_ids.duplicate()

func get_resolved_dungeon_node_ids() -> Array[int]:
	return resolved_dungeon_node_ids.duplicate()

func get_occupied_dungeon_node_ids() -> Array[int]:
	var occupied_ids: Array[int] = []
	for pawn in dungeon_map_pawns.values():
		var map_pawn: Variant = pawn
		if map_pawn == null or map_pawn.current_node_id < 0:
			continue
		_add_node_id(occupied_ids, map_pawn.current_node_id)

	return occupied_ids

func get_last_visited_dungeon_node_id() -> int:
	var current_node_id := get_current_dungeon_node_id()
	if current_node_id >= 0:
		return current_node_id

	if visited_dungeon_node_ids.is_empty():
		return -1

	return int(visited_dungeon_node_ids[visited_dungeon_node_ids.size() - 1])

func get_descriptor_connected_node_ids(node_id: int) -> Array[int]:
	var connected_ids: Array[int] = []
	var descriptor := _descriptor_for_node_id(node_id)
	var raw_connections: Variant = descriptor.get("connections", [])
	if raw_connections is Array:
		for raw_connected_id in raw_connections:
			var connected_id := int(raw_connected_id)
			if connected_id >= 0:
				_add_node_id(connected_ids, connected_id)

	if connected_ids.is_empty():
		connected_ids = _linear_descriptor_neighbors(node_id)

	return connected_ids

## Requests path-based travel for the selected dungeon pawn.
func request_selected_dungeon_pawn_travel(destination_node_id: int) -> Dictionary:
	var pawn: Variant = get_selected_dungeon_map_pawn()
	if pawn == null:
		return _travel_request_result(false, "missing_pawn", [], false)

	return request_dungeon_pawn_travel(str(pawn.pawn_id), destination_node_id)

func can_request_selected_dungeon_pawn_travel(destination_node_id: int) -> bool:
	var pawn: Variant = get_selected_dungeon_map_pawn()
	if pawn == null or destination_node_id < 0:
		return false
	if pawn.current_node_id == destination_node_id:
		return false
	if bool(pawn.is_locked_by_event) or int(pawn.travel_state) == DungeonMapPawnStateScript.IN_EVENT:
		return false
	if not bool(pawn.is_active()):
		return false

	return not get_dungeon_pawn_travel_path(str(pawn.pawn_id), destination_node_id).is_empty()

## Validates a pawn travel order and fans accepted local-leader orders out to AutoPilot followers.
func request_dungeon_pawn_travel(pawn_id: String, destination_node_id: int) -> Dictionary:
	var result := _request_single_dungeon_pawn_travel(pawn_id, destination_node_id)
	if bool(result.get("accepted", false)):
		result[TRAVEL_RESULT_AUTOPILOT_FOLLOW_RESULTS] = _request_autopilot_follow_orders(pawn_id, destination_node_id)
	return result

func get_dungeon_pawn_travel_path(pawn_id: String, destination_node_id: int) -> Array[int]:
	var pawn: Variant = get_dungeon_map_pawn(pawn_id)
	if pawn == null or pawn.current_node_id < 0 or destination_node_id < 0:
		return []

	var allowed_node_ids: Array[int] = get_allowed_dungeon_path_node_ids()
	var connection_graph: Dictionary = get_dungeon_connection_graph()
	return DungeonPathfinderScript.find_path(
		int(pawn.current_node_id),
		destination_node_id,
		allowed_node_ids,
		connection_graph
	)

func get_allowed_dungeon_path_node_ids() -> Array[int]:
	var allowed_node_ids: Array[int] = []
	#; Node state invariant: resolved nodes are visited and revealed; visited nodes are revealed.
	for node_id in revealed_dungeon_node_ids:
		_add_node_id(allowed_node_ids, node_id)

	for raw_pawn_id in active_dungeon_pawn_ids:
		var pawn: Variant = get_dungeon_map_pawn(str(raw_pawn_id))
		if pawn != null and bool(pawn.is_active()):
			_add_node_id(allowed_node_ids, int(pawn.current_node_id))

	return allowed_node_ids

func get_dungeon_connection_graph() -> Dictionary:
	return DungeonPathfinderScript.connection_graph_from_descriptors(dungeon_node_descriptors)

func export_memories_to(class_memory_awards: Dictionary) -> int:
	if memories_exported:
		return 0

	memories_exported = true
	var awarded_memories: int = max(memories, 0)
	if awarded_memories <= 0:
		return 0

	var current_total: int = int(class_memory_awards.get(selected_character, 0))
	class_memory_awards[selected_character] = current_total + awarded_memories
	return awarded_memories

func register_combat_result(result: Variant) -> void:
	if result == null:
		return

	damage_dealt += max(result.damage_dealt, 0)
	damage_taken += max(result.damage_taken, 0)
	actions_used += max(result.actions_used, 0)
	_apply_combat_participant_results(result.get("participant_results"))

	if not result.victory:
		end_run(result.end_reason if not str(result.end_reason).is_empty() else END_REASON_DEFEAT)
		return

	#; Combat rewards are party-wide run progress in the current single-party model.
	grant_rewards(result.memories_awarded, result.gold_awarded)
	fights_completed += 1
	complete_dungeon_node(result.node_id)

	if result.is_boss:
		boss_defeated = true
		end_run(END_REASON_VICTORY)
	else:
		regular_fights_completed += 1

func _apply_combat_participant_results(raw_participant_results: Variant) -> void:
	if not (raw_participant_results is Array):
		return

	for raw_result in raw_participant_results:
		if raw_result is Dictionary:
			_apply_player_participant_result(raw_result)

func _apply_player_participant_result(participant_result: Dictionary) -> void:
	if str(participant_result.get(CombatResultScript.PARTICIPANT_SIDE_ID, "")) != CombatResultScript.SIDE_ID_PLAYER:
		return
	if player_party_state == null:
		return

	var combatant_id := str(participant_result.get(CombatResultScript.PARTICIPANT_COMBATANT_ID, "")).strip_edges()
	if combatant_id.is_empty():
		return

	var member: Variant = player_party_state.get_member_for_combatant_id(combatant_id)
	if member == null or member.combatant_state == null:
		return

	var combatant_state: Variant = member.combatant_state
	var max_hp_value := int(participant_result.get(CombatResultScript.PARTICIPANT_MAX_HP, combatant_state.max_hp))
	var hp_after_value := int(participant_result.get(CombatResultScript.PARTICIPANT_HP_AFTER, combatant_state.current_hp))
	if max_hp_value > 0:
		combatant_state.set_max_hp(max_hp_value, false)
	combatant_state.set_current_hp(hp_after_value)

func _request_single_dungeon_pawn_travel(pawn_id: String, destination_node_id: int) -> Dictionary:
	var pawn: Variant = get_dungeon_map_pawn(pawn_id)
	if pawn == null:
		return _travel_request_result(false, "missing_pawn", [], false)
	if destination_node_id < 0:
		return _travel_request_result(false, "invalid_destination", [], false)
	if pawn.current_node_id == destination_node_id:
		return _travel_request_result(false, "already_at_destination", [], false)
	if bool(pawn.is_locked_by_event) or int(pawn.travel_state) == DungeonMapPawnStateScript.IN_EVENT:
		return _travel_request_result(false, "pawn_locked_by_event", [], false)
	if not bool(pawn.is_active()):
		return _travel_request_result(false, "pawn_inactive", [], false)

	var path: Array[int] = get_dungeon_pawn_travel_path(pawn_id, destination_node_id)
	if path.is_empty():
		return _travel_request_result(false, "unreachable_destination", [], false)

	if int(pawn.travel_state) == DungeonMapPawnStateScript.TRAVELING:
		if not ALLOW_DESTINATION_REPLACE_DURING_TRAVEL:
			return _travel_request_result(false, "replacement_disabled", path, false)
		if not pawn.request_destination_replacement(destination_node_id):
			return _travel_request_result(false, "replacement_rejected", path, false)
		return _travel_request_result(true, "", path, true)

	if not pawn.set_travel_order(
		destination_node_id,
		path,
		NODE_TRAVEL_TIME,
		VISUAL_NODE_STEPS_PER_REAL_SECOND
	):
		return _travel_request_result(false, "travel_order_rejected", path, false)

	return _travel_request_result(true, "", path, false)

## Requests matching same-destination travel for active AutoPilot pawns following the local leader.
func _request_autopilot_follow_orders(leader_pawn_id: String, destination_node_id: int) -> Array[Dictionary]:
	var follow_results: Array[Dictionary] = []
	if not _is_local_leader_pawn_id(leader_pawn_id):
		return follow_results
	if player_party_state == null:
		return follow_results

	for member in player_party_state.get_active_members():
		var party_member: Variant = member
		if party_member == null or not bool(party_member.should_follow_leader()):
			continue

		var follower_pawn_id := str(party_member.map_pawn_id)
		if follower_pawn_id.is_empty() or follower_pawn_id == leader_pawn_id:
			continue

		var follower_result := _request_single_dungeon_pawn_travel(follower_pawn_id, destination_node_id)
		follow_results.append(_autopilot_follow_result(follower_pawn_id, follower_result))

	return follow_results

func _mark_dungeon_node_visit_state(node_id: int) -> void:
	_add_node_id(visited_dungeon_node_ids, node_id)
	reveal_dungeon_node(node_id)
	reveal_connected_dungeon_nodes(node_id)
	current_node_index = max(current_node_index, node_id)

#; Completion can arrive from combat/encounter handoffs without an explicit pawn id.
func _completion_pawn_ids_for_node(node_id: int, pawn_id: String = "") -> Array[String]:
	var completion_pawn_ids: Array[String] = []
	if not pawn_id.is_empty() and get_dungeon_map_pawn(pawn_id) != null:
		_add_pawn_id(completion_pawn_ids, pawn_id)

	for locked_pawn_id in get_event_locked_dungeon_pawn_ids(node_id):
		_add_pawn_id(completion_pawn_ids, locked_pawn_id)

	return completion_pawn_ids

func _sync_current_pawn_node(node_id: int, pawn_id: String = "") -> bool:
	var pawn: Variant = null
	if not pawn_id.is_empty():
		pawn = get_dungeon_map_pawn(pawn_id)
		if pawn == null:
			return false
	else:
		pawn = get_selected_dungeon_map_pawn()
	if pawn == null:
		return false

	pawn.set_current_node_id(node_id)
	if _is_selected_dungeon_pawn_id(str(pawn.pawn_id)):
		current_dungeon_node_id = node_id
	return true

func _is_pawn_locked_for_event_node(pawn: Variant, node_id: int) -> bool:
	return pawn != null \
		and bool(pawn.is_locked_by_event) \
		and int(pawn.active_event_node_id) == node_id

func _is_selected_dungeon_pawn_id(pawn_id: String) -> bool:
	if pawn_id.is_empty():
		return false

	var selected_pawn: Variant = get_selected_dungeon_map_pawn()
	return selected_pawn != null and str(selected_pawn.pawn_id) == pawn_id

func _is_local_leader_pawn_id(pawn_id: String) -> bool:
	var member: Variant = _party_member_for_pawn_id(pawn_id)
	if member == null or player_party_state == null:
		return false
	if str(member.party_member_id) != str(player_party_state.leader_member_id):
		return false

	return bool(member.is_unlocked) \
		and bool(member.is_active) \
		and int(member.control_mode) == PartyControlModeScript.LOCAL_PLAYER

func _party_member_for_pawn_id(pawn_id: String) -> Variant:
	if player_party_state == null or pawn_id.is_empty():
		return null

	for raw_member in player_party_state.members.values():
		var member: Variant = raw_member
		if member != null and str(member.map_pawn_id) == pawn_id:
			return member

	return null

func _autopilot_follow_result(pawn_id: String, result: Dictionary) -> Dictionary:
	return {
		"pawn_id": pawn_id,
		"accepted": bool(result.get("accepted", false)),
		"reason": str(result.get("reason", "")),
		"path": _duplicate_path_result(result.get("path", [])),
		"queued_replacement": bool(result.get("queued_replacement", false)),
	}

func _duplicate_path_result(raw_path: Variant) -> Array:
	if raw_path is Array:
		return raw_path.duplicate()

	return []

func _descriptor_for_node_id(node_id: int) -> Dictionary:
	for raw_descriptor in dungeon_node_descriptors:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		if int(descriptor.get("id", -1)) == node_id:
			return descriptor

	return {}

func _linear_descriptor_neighbors(node_id: int) -> Array[int]:
	var neighbor_ids: Array[int] = []
	var descriptor_ids: Array[int] = []
	for raw_descriptor in dungeon_node_descriptors:
		if raw_descriptor is Dictionary:
			_add_node_id(descriptor_ids, int(raw_descriptor.get("id", -1)))

	if descriptor_ids.is_empty() and total_nodes > 0:
		for index in range(total_nodes):
			descriptor_ids.append(index)

	var descriptor_index := descriptor_ids.find(node_id)
	if descriptor_index < 0:
		return neighbor_ids
	if descriptor_index > 0:
		neighbor_ids.append(descriptor_ids[descriptor_index - 1])
	if descriptor_index < descriptor_ids.size() - 1:
		neighbor_ids.append(descriptor_ids[descriptor_index + 1])

	return neighbor_ids

func _add_node_id(target_ids: Array[int], node_id: int) -> bool:
	if node_id < 0 or target_ids.has(node_id):
		return false

	target_ids.append(node_id)
	target_ids.sort()
	return true

func _add_pawn_id(target_ids: Array[String], pawn_id: String) -> bool:
	if pawn_id.is_empty() or target_ids.has(pawn_id):
		return false

	target_ids.append(pawn_id)
	return true

func _dungeon_pawn_id_for_member(party_member_id: String) -> String:
	var normalized := party_member_id.strip_edges().to_lower().replace(" ", "_")
	if normalized.begins_with("party_member."):
		normalized = normalized.substr("party_member.".length())
	if normalized.is_empty():
		normalized = "member"

	return "map_pawn.%s" % normalized

func _travel_request_result(accepted: bool, reason: String, path: Array, queued_replacement: bool) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"path": path.duplicate(),
		"queued_replacement": queued_replacement,
	}

func _tick_run_stat_modifiers(seconds: float) -> void:
	if seconds <= 0.0 or run_stat_modifiers.is_empty():
		return

	var active_modifiers: Array[Dictionary] = []
	for modifier in run_stat_modifiers:
		if bool(modifier.get("permanent", false)):
			active_modifiers.append(modifier)
			continue

		var remaining_seconds := float(modifier.get("remaining_seconds", 0.0)) - seconds
		if remaining_seconds > 0.0:
			modifier["remaining_seconds"] = remaining_seconds
			active_modifiers.append(modifier)

	run_stat_modifiers = active_modifiers
	_sync_player_state_modifiers()
	_recalculate_player_max_hp(false)

func _recalculate_player_max_hp(heal_to_full: bool) -> void:
	_sync_player_state_modifiers()
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return

	combatant_state.recalculate_max_hp(heal_to_full)

func _player_combatant_state() -> Variant:
	if player_party_state == null:
		return null

	return player_party_state.get_selected_combatant_state()

func _sync_player_state_modifiers() -> void:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return

	combatant_state.set_runtime_modifiers(run_stat_modifiers)

func _effect_id(effect_data: Dictionary) -> StringName:
	var value: Variant = effect_data.get("id", &"")
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return &""
