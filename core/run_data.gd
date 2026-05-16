## Stores all mutable state for a run, including selection, timer, encounters, rewards, and combat totals.
class_name RunData
extends RefCounted

const DungeonMapPawnStateScript := preload("res://core/dungeon/dungeon_map_pawn_state.gd")
const DungeonPathfinderScript := preload("res://core/dungeon/dungeon_pathfinder.gd")
const PlayerPartyStateScript := preload("res://core/party/player_party_state.gd")

const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"
const DEFAULT_CHARACTER := "Warrior"
const DEFAULT_DIFFICULTY := "normal"
const DEFAULT_RUN_TIME_SECONDS := 1000.0
const START_DUNGEON_NODE_ID := 0
const LOCAL_OWNER_PLAYER_ID := "local"
const NODE_STEP_DUNGEON_TIME_SECONDS := 1.0
const VISUAL_NODE_STEPS_PER_REAL_SECOND := 4.0
const ALLOW_DESTINATION_REPLACE_DURING_TRAVEL := true
const ALLOW_CANCEL_AFTER_CURRENT_STEP := true
const NODE_TRAVEL_TIME_SECONDS := 10.0
const EMPTY_NODE_TIME_SECONDS := 1.0
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
var player_base_stats: Dictionary = {}
var player_current_hp: int = 0
var player_max_hp: int = 0
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
	player_base_stats.clear()
	player_current_hp = 0
	player_max_hp = 0
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
	current_encounter_is_boss = false

func initialize_player_state(profile: Resource, profile_path: String = "") -> void:
	player_base_stats = {
		STAT_STRENGTH: _profile_stat(profile, "strength", 5),
		STAT_DEXTERITY: _profile_stat(profile, "dexterity", 5),
		STAT_INTELLIGENCE: _profile_stat(profile, "intelligence", 5),
		STAT_VITALITY: _profile_stat(profile, "vitality", 5),
	}
	player_party_state = PlayerPartyStateScript.new()
	player_party_state.configure_single_member(selected_character, profile_path, profile)
	_sync_player_state_modifiers()
	_sync_player_legacy_fields_from_state()

func get_effective_stats() -> Dictionary:
	return {
		STAT_STRENGTH: get_effective_stat(STAT_STRENGTH),
		STAT_DEXTERITY: get_effective_stat(STAT_DEXTERITY),
		STAT_INTELLIGENCE: get_effective_stat(STAT_INTELLIGENCE),
		STAT_VITALITY: get_effective_stat(STAT_VITALITY),
	}

func get_effective_stat(stat_id: String) -> int:
	var canonical_stat_id := _canonical_stat_id(stat_id)
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state != null:
		_sync_player_state_modifiers()
		return combatant_state.get_effective_stat(canonical_stat_id)

	var value := int(player_base_stats.get(canonical_stat_id, 0))
	for modifier in run_stat_modifiers:
		if str(modifier.get("stat_id", "")) == canonical_stat_id:
			value += int(modifier.get("amount", 0))

	return max(value, 0)

func apply_player_stats_to_combatant(combatant: Variant) -> void:
	if combatant == null:
		return

	var combatant_state: Variant = _player_combatant_state()
	if combatant_state != null:
		_sync_player_state_modifiers()
		combatant_state.apply_stats_to_combatant(combatant)
		return

	combatant.strength = get_effective_stat(STAT_STRENGTH)
	combatant.dexterity = get_effective_stat(STAT_DEXTERITY)
	combatant.intelligence = get_effective_stat(STAT_INTELLIGENCE)
	combatant.vitality = get_effective_stat(STAT_VITALITY)

func set_player_hp_from_combat(current_hp: int, max_hp: int = -1) -> void:
	if max_hp > 0:
		player_max_hp = max_hp
	player_current_hp = clamp(current_hp, 0, max(player_max_hp, 1))
	_sync_player_state_hp_from_legacy()

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
			var previous_hp := player_current_hp
			set_player_hp_from_combat(player_current_hp - max(amount, 0))
			var actual_damage := previous_hp - player_current_hp
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
				"stat_id": _canonical_stat_id(str(effect_data.get("stat", STAT_STRENGTH))),
				"amount": amount,
				"permanent": permanent,
				"remaining_seconds": duration_seconds,
			})
			_sync_player_state_modifiers()
			_recalculate_player_max_hp(false)
			outcome["stat_modifiers_added"] = 1

	return outcome

func is_player_defeated() -> bool:
	return player_current_hp <= 0

func set_encounter(
	node_id: int,
	node_type: String,
	enemy_profile_path: String,
	is_boss: bool,
	default_enemy_profile_path: String
) -> void:
	current_encounter_node_id = node_id
	current_encounter_node_type = node_type
	current_encounter_enemy_profile_path = enemy_profile_path if not enemy_profile_path.is_empty() else default_enemy_profile_path
	current_encounter_is_boss = is_boss
	pending_combat_result = null

func get_current_encounter(default_enemy_profile_path: String) -> Dictionary:
	return {
		"node_id": current_encounter_node_id,
		"node_type": current_encounter_node_type,
		"enemy_profile_path": current_encounter_enemy_profile_path if not current_encounter_enemy_profile_path.is_empty() else default_enemy_profile_path,
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
	if get_selected_dungeon_map_pawn() == pawn:
		current_dungeon_node_id = node_id
	return true

func get_current_dungeon_node_id() -> int:
	var pawn: Variant = get_selected_dungeon_map_pawn()
	if pawn != null and pawn.current_node_id >= 0:
		return pawn.current_node_id

	return current_dungeon_node_id

func mark_dungeon_node_visited(node_id: int, pawn_id: String = "") -> void:
	if node_id < 0:
		return

	_add_node_id(visited_dungeon_node_ids, node_id)
	reveal_dungeon_node(node_id)
	reveal_connected_dungeon_nodes(node_id)
	current_node_index = max(current_node_index, node_id)
	current_dungeon_node_id = node_id
	_sync_current_pawn_node(node_id, pawn_id)

func mark_dungeon_node_resolved(node_id: int) -> void:
	_add_node_id(resolved_dungeon_node_ids, node_id)

func complete_dungeon_node(node_id: int, pawn_id: String = "") -> void:
	mark_dungeon_node_visited(node_id, pawn_id)
	mark_dungeon_node_resolved(node_id)
	unlock_dungeon_pawns_for_event_node(node_id)

## Unlocks any pawn whose active event was resolved at the provided node.
func unlock_dungeon_pawns_for_event_node(node_id: int) -> void:
	if node_id < 0:
		return

	for raw_pawn in dungeon_map_pawns.values():
		var pawn: Variant = raw_pawn
		if pawn == null or int(pawn.active_event_node_id) != node_id:
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

## Validates and stores a travel order or pending replacement for one pawn.
func request_dungeon_pawn_travel(pawn_id: String, destination_node_id: int) -> Dictionary:
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
		NODE_STEP_DUNGEON_TIME_SECONDS,
		VISUAL_NODE_STEPS_PER_REAL_SECOND
	):
		return _travel_request_result(false, "travel_order_rejected", path, false)

	return _travel_request_result(true, "", path, false)

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
	for node_id in revealed_dungeon_node_ids:
		_add_node_id(allowed_node_ids, node_id)
	for node_id in visited_dungeon_node_ids:
		_add_node_id(allowed_node_ids, node_id)
	for node_id in resolved_dungeon_node_ids:
		_add_node_id(allowed_node_ids, node_id)

	var selected_pawn: Variant = get_selected_dungeon_map_pawn()
	if selected_pawn != null:
		_add_node_id(allowed_node_ids, int(selected_pawn.current_node_id))

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
	var player_hp_after: Variant = result.get("player_hp_after")
	var result_player_max_hp: Variant = result.get("player_max_hp")
	if (player_hp_after is int or player_hp_after is float) and (result_player_max_hp is int or result_player_max_hp is float) and int(result_player_max_hp) > 0:
		set_player_hp_from_combat(int(player_hp_after), int(result_player_max_hp))

	if not result.victory:
		end_run(result.end_reason if not str(result.end_reason).is_empty() else END_REASON_DEFEAT)
		return

	grant_rewards(result.memories_awarded, result.gold_awarded)
	fights_completed += 1
	complete_dungeon_node(result.node_id)

	if result.is_boss:
		boss_defeated = true
		end_run(END_REASON_VICTORY)
	else:
		regular_fights_completed += 1

func _sync_current_pawn_node(node_id: int, pawn_id: String = "") -> void:
	var pawn: Variant = null
	if not pawn_id.is_empty():
		pawn = get_dungeon_map_pawn(pawn_id)
	if pawn == null:
		pawn = get_selected_dungeon_map_pawn()
	if pawn == null:
		return

	pawn.set_current_node_id(node_id)

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
	player_max_hp = max(get_effective_stat(STAT_VITALITY), 1) * 10
	if heal_to_full:
		player_current_hp = player_max_hp
	else:
		player_current_hp = clamp(player_current_hp, 0, player_max_hp)
	_sync_player_state_hp_from_legacy()

func _player_combatant_state() -> Variant:
	if player_party_state == null:
		return null

	return player_party_state.get_selected_combatant_state()

func _sync_player_state_modifiers() -> void:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return

	combatant_state.set_runtime_modifiers(run_stat_modifiers)

func _sync_player_legacy_fields_from_state() -> void:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return

	#; Legacy player fields remain as compatibility mirrors until later phases migrate call sites.
	player_base_stats = combatant_state.stats.duplicate()
	player_max_hp = combatant_state.max_hp
	player_current_hp = combatant_state.current_hp

func _sync_player_state_hp_from_legacy() -> void:
	var combatant_state: Variant = _player_combatant_state()
	if combatant_state == null:
		return

	combatant_state.set_runtime_modifiers(run_stat_modifiers)
	combatant_state.set_max_hp(player_max_hp, false)
	combatant_state.set_current_hp(player_current_hp)

func _profile_stat(profile: Resource, field_name: String, default_value: int) -> int:
	if profile == null:
		return default_value

	var value: Variant = profile.get(field_name)
	if value is int or value is float:
		return int(value)

	return default_value

func _canonical_stat_id(stat_id: String) -> String:
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

func _effect_id(effect_data: Dictionary) -> StringName:
	var value: Variant = effect_data.get("id", &"")
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return &""
