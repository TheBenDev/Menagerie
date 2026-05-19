## Autoload manager for dungeon generation, validation, map state changes, and dungeon snapshots.
extends Node

const DungeonFloorGeneratorScript := preload("res://core/dungeon/dungeon_floor_generator.gd")
const DungeonEncounterResolverScript := preload("res://core/dungeon/encounters/dungeon_encounter_resolver.gd")
const DungeonMapPawnStateScript := preload("res://core/dungeon/dungeon_map_pawn_state.gd")
const DungeonMovementCoordinatorScript := preload("res://core/dungeon/dungeon_movement_coordinator.gd")
const DungeonNodeDataScript := preload("res://core/dungeon/dungeon_node_data.gd")
const DungeonPathfinderScript := preload("res://core/dungeon/dungeon_pathfinder.gd")
const PartyControlModeScript := preload("res://core/party/party_control_mode.gd")
const CombatPayloadValidatorScript := preload("res://core/combat/combat_payload_validator.gd")
const DEFAULT_DUNGEON_GENERATION_CONFIG := preload("res://core/dungeon/default_dungeon_floor_generation_config.tres")
const DEFAULT_DUNGEON_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_encounter_pool.tres")
const DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres")
const DEFAULT_DUNGEON_ABILITY_POOL := preload("res://core/dungeon/abilities/default_dungeon_ability_pool.tres")

const LOCAL_OWNER_PLAYER_ID := "local"
const NODE_TRAVEL_TIME := 1.0
const VISUAL_NODE_STEPS_PER_REAL_SECOND := 4.0
const ALLOW_DESTINATION_REPLACE_DURING_TRAVEL := true
const TRAVEL_RESULT_AUTOPILOT_FOLLOW_RESULTS := "autopilot_follow_results"

func initialize_dungeon_for_run(run_data: Variant) -> void:
	if run_data == null:
		push_error("DungeonManager cannot initialize a dungeon without run data.")
		return

	var difficulty_id: StringName = _active_difficulty_id()
	if String(difficulty_id).is_empty():
		push_error("DungeonManager cannot initialize a dungeon without DifficultyService.")
		return

	run_data.dungeon_node_descriptors = DungeonFloorGeneratorScript.generate_floor(
		run_data.dungeon_seed,
		run_data.dungeon_floor_layer,
		String(difficulty_id),
		DEFAULT_DUNGEON_GENERATION_CONFIG,
		DEFAULT_DUNGEON_ENCOUNTER_POOL,
		DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL
	)
	if not validate_descriptors(run_data.dungeon_node_descriptors):
		return

	configure_map_metadata(
		run_data,
		run_data.dungeon_node_descriptors.size(),
		_boss_descriptor_id(run_data.dungeon_node_descriptors)
	)
	initialize_map_state_for_run(run_data, RunData.START_DUNGEON_NODE_ID)

func initialize_map_state_for_run(run_data: Variant, start_node_id: int = RunData.START_DUNGEON_NODE_ID) -> void:
	if run_data == null:
		push_error("DungeonManager cannot initialize map state without run data.")
		return
	if run_data.dungeon_node_descriptors.is_empty():
		push_error("DungeonManager cannot initialize map state before descriptors exist.")
		return

	run_data.dungeon_map_pawns.clear()
	run_data.active_dungeon_pawn_ids.clear()
	run_data.revealed_dungeon_node_ids.clear()
	run_data.resolved_dungeon_node_ids.clear()
	run_data.visited_dungeon_node_ids.clear()
	run_data.current_node_index = 0
	run_data.current_dungeon_node_id = -1

	var active_members: Array = []
	if run_data.player_party_state != null:
		active_members = run_data.player_party_state.get_active_members()

	for member in active_members:
		if member == null or member.is_inactive():
			continue

		var pawn_id: String = _dungeon_pawn_id_for_member(str(member.party_member_id))
		var pawn: Variant = DungeonMapPawnStateScript.new()
		pawn.configure_for_party_member(pawn_id, member, start_node_id, LOCAL_OWNER_PLAYER_ID)
		run_data.dungeon_map_pawns[pawn_id] = pawn
		run_data.active_dungeon_pawn_ids.append(pawn_id)
		member.map_pawn_id = pawn_id

	mark_node_visited(run_data, start_node_id, &"")

func validate_descriptors(descriptors: Array) -> bool:
	if not DungeonFloorGeneratorScript.validate_descriptors(descriptors):
		push_error("Dungeon descriptors failed validation.")
		return false

	return true

func request_pawn_travel(run_data: Variant, pawn_id: StringName, destination_node_id: int) -> Dictionary:
	if run_data == null:
		return {"accepted": false, "reason": "missing_run_data", "path": [], "queued_replacement": false}

	var result: Dictionary = _request_single_pawn_travel(run_data, String(pawn_id), destination_node_id)
	if bool(result.get("accepted", false)):
		result[TRAVEL_RESULT_AUTOPILOT_FOLLOW_RESULTS] = _request_autopilot_follow_orders(run_data, String(pawn_id), destination_node_id)
	return result

func request_selected_pawn_travel(run_data: Variant, destination_node_id: int) -> Dictionary:
	if run_data == null:
		return {"accepted": false, "reason": "missing_run_data", "path": [], "queued_replacement": false}

	var pawn: Variant = get_selected_pawn(run_data)
	if pawn == null:
		return _travel_request_result(false, "missing_pawn", [], false)

	return request_pawn_travel(run_data, StringName(str(pawn.pawn_id)), destination_node_id)

func can_request_selected_pawn_travel(run_data: Variant, destination_node_id: int) -> bool:
	var pawn: Variant = get_selected_pawn(run_data)
	if pawn == null or destination_node_id < 0:
		return false
	if int(pawn.current_node_id) == destination_node_id:
		return false
	if bool(pawn.is_locked_by_event) or int(pawn.travel_state) == DungeonMapPawnStateScript.IN_EVENT:
		return false
	if not bool(pawn.is_active()):
		return false

	return not get_pawn_travel_path(run_data, str(pawn.pawn_id), destination_node_id).is_empty()

func can_request_selected_pawn_travel_snapshot(dungeon_snapshot: Dictionary, destination_node_id: int) -> bool:
	var selected_pawn_id: String = str(dungeon_snapshot.get("selected_pawn_id", ""))
	var pawns: Dictionary = dungeon_snapshot.get("pawns", {})
	var pawn: Dictionary = pawns.get(selected_pawn_id, {})
	if pawn.is_empty() or destination_node_id < 0:
		return false
	var pawn_current_node_id: int = int(pawn.get("current_node_id", -1))
	if pawn_current_node_id == destination_node_id:
		return false
	if bool(pawn.get("is_locked_by_event", false)) or int(pawn.get("travel_state", -1)) == DungeonMapPawnStateScript.IN_EVENT:
		return false
	if int(pawn.get("travel_state", -1)) == DungeonMapPawnStateScript.INACTIVE or int(pawn.get("control_mode", -1)) == PartyControlModeScript.INACTIVE:
		return false

	var path: Array[int] = DungeonPathfinderScript.find_path(
		pawn_current_node_id,
		destination_node_id,
		_allowed_path_node_ids_from_snapshot(dungeon_snapshot),
		DungeonPathfinderScript.connection_graph_from_descriptors(dungeon_snapshot.get("descriptors", []))
	)
	return not path.is_empty()

func has_active_travel_orders(run_data: Variant) -> bool:
	return DungeonMovementCoordinatorScript.has_active_travel_orders(run_data)

func advance_travel_one_step(run_data: Variant, interrupt_node_ids: Array = []) -> Dictionary:
	return DungeonMovementCoordinatorScript.advance_one_step(run_data, interrupt_node_ids, self)

func mark_node_visited(run_data: Variant, node_id: int, pawn_id: StringName) -> void:
	if run_data == null or node_id < 0:
		return

	_mark_node_visit_state(run_data, node_id)
	var synced_pawn: bool = _sync_current_pawn_node(run_data, node_id, String(pawn_id))
	if not synced_pawn and String(pawn_id).is_empty():
		run_data.current_dungeon_node_id = node_id

func resolve_node(run_data: Variant, node_id: int, pawn_id: StringName = &"") -> void:
	if run_data == null or node_id < 0:
		return

	var completion_pawn_ids: Array[String] = _completion_pawn_ids_for_node(run_data, node_id, String(pawn_id))
	if completion_pawn_ids.is_empty():
		if String(pawn_id).is_empty():
			mark_node_visited(run_data, node_id, &"")
		else:
			_mark_node_visit_state(run_data, node_id)
	else:
		_mark_node_visit_state(run_data, node_id)
		for completion_pawn_id: String in completion_pawn_ids:
			_sync_current_pawn_node(run_data, node_id, completion_pawn_id)
	_mark_node_resolved(run_data, node_id)
	unlock_pawns_for_event_node(run_data, node_id)

func is_node_resolved(run_data: Variant, node_id: int) -> bool:
	return run_data != null and run_data.resolved_dungeon_node_ids.has(node_id)

func is_player_defeated(run_data: Variant) -> bool:
	var party_manager: Variant = _party_manager()
	return party_manager != null and party_manager.is_player_defeated(run_data)

func get_selected_pawn(run_data: Variant) -> Variant:
	if run_data == null:
		return null

	if run_data.player_party_state != null:
		var member: Variant = run_data.player_party_state.get_selected_member()
		if member == null:
			member = run_data.player_party_state.get_leader()
		if member != null and not str(member.map_pawn_id).is_empty():
			var member_pawn: Variant = get_pawn(run_data, str(member.map_pawn_id))
			if member_pawn != null:
				return member_pawn

	for pawn_id in run_data.active_dungeon_pawn_ids:
		var pawn: Variant = get_pawn(run_data, str(pawn_id))
		if pawn != null:
			return pawn

	return null

func get_pawn(run_data: Variant, pawn_id: String) -> Variant:
	if run_data == null:
		return null

	return run_data.get_dungeon_map_pawn(pawn_id)

func has_map_pawns(run_data: Variant) -> bool:
	return run_data != null and not run_data.dungeon_map_pawns.is_empty()

func configure_map_metadata(run_data: Variant, total_nodes: int, boss_node_id: int) -> void:
	if run_data == null:
		return

	run_data.total_nodes = max(total_nodes, 0)
	run_data.boss_node_index = max(boss_node_id, 0)

func _boss_descriptor_id(descriptors: Array) -> int:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		if bool(descriptor.get("is_boss", false)) or str(descriptor.get("type", "")) == DungeonNodeDataScript.TYPE_BOSS:
			return int(descriptor.get("id", descriptors.size() - 1))

	return max(descriptors.size() - 1, 0)

func current_node_id(run_data: Variant) -> int:
	var pawn: Variant = get_selected_pawn(run_data)
	if pawn != null and int(pawn.current_node_id) >= 0:
		return int(pawn.current_node_id)

	return int(run_data.current_dungeon_node_id) if run_data != null else -1

func move_pawn_to_node(run_data: Variant, pawn_id: String, node_id: int) -> bool:
	var pawn: Variant = get_pawn(run_data, pawn_id)
	if pawn == null or node_id < 0:
		return false

	pawn.set_current_node_id(node_id)
	run_data.current_node_index = max(int(run_data.current_node_index), node_id)
	if _is_selected_pawn_id(run_data, str(pawn.pawn_id)):
		run_data.current_dungeon_node_id = node_id
	return true

func get_pawn_travel_path(run_data: Variant, pawn_id: String, destination_node_id: int) -> Array[int]:
	var pawn: Variant = get_pawn(run_data, pawn_id)
	if pawn == null or int(pawn.current_node_id) < 0 or destination_node_id < 0:
		return []

	return DungeonPathfinderScript.find_path(
		int(pawn.current_node_id),
		destination_node_id,
		_allowed_path_node_ids(run_data),
		DungeonPathfinderScript.connection_graph_from_descriptors(run_data.dungeon_node_descriptors)
	)

func travel_step_game_seconds() -> float:
	return NODE_TRAVEL_TIME

func visual_node_steps_per_real_second() -> float:
	return VISUAL_NODE_STEPS_PER_REAL_SECOND

func lock_pawn_for_event(run_data: Variant, pawn_id: String, node_id: int) -> void:
	var pawn: Variant = get_pawn(run_data, pawn_id)
	if pawn != null:
		pawn.lock_for_event(node_id)

func apply_encounter_result(run_data: Variant, encounter_result: Dictionary) -> Dictionary:
	var outcome := {
		"handled": false,
		"damage_taken": 0,
		"stat_modifiers_added": 0,
	}
	if run_data == null:
		return outcome

	var mode := str(encounter_result.get("mode", "complete"))
	if mode != "complete":
		push_warning("Unsupported dungeon encounter result mode: %s" % mode)
		return outcome

	var encounter_id := StringName(str(encounter_result.get("encounter_id", "")))
	var encounter_data: Resource = DungeonEncounterResolverScript.encounter_for_id(DEFAULT_DUNGEON_ENCOUNTER_POOL, encounter_id)
	var choice_index := int(encounter_result.get("choice_index", -1))
	var choice_data: Dictionary = DungeonEncounterResolverScript.choice_for_index(encounter_data, choice_index)
	var party_manager: Variant = _party_manager()
	if party_manager == null:
		push_error("DungeonManager cannot apply encounter result without PartyManager.")
		return outcome

	var effect_outcome: Dictionary = party_manager.resolve_encounter_choice_effects(run_data, choice_data)
	outcome["handled"] = true
	outcome["damage_taken"] = int(effect_outcome.get("damage_taken", 0))
	outcome["stat_modifiers_added"] = int(effect_outcome.get("stat_modifiers_added", 0))
	return outcome

func get_dungeon_encounter(encounter_id: StringName) -> Resource:
	return DungeonEncounterResolverScript.encounter_for_id(DEFAULT_DUNGEON_ENCOUNTER_POOL, encounter_id)

func get_dungeon_encounter_scene(encounter_id: StringName) -> PackedScene:
	return DungeonEncounterResolverScript.scene_for_encounter(DEFAULT_DUNGEON_ENCOUNTER_POOL, get_dungeon_encounter(encounter_id))

func get_dungeon_combat_encounter(encounter_id: StringName) -> Resource:
	if String(encounter_id).is_empty():
		return null
	return DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL.call("get_encounter", encounter_id) as Resource

func get_dungeon_abilities(slot_count: int = 3) -> Array:
	if DEFAULT_DUNGEON_ABILITY_POOL == null:
		return []

	return DEFAULT_DUNGEON_ABILITY_POOL.get_hotbar_abilities(slot_count)

func complete_combat_node(run_data: Variant, combat_result: Variant) -> void:
	if run_data != null and combat_result != null:
		resolve_node(run_data, int(combat_result.node_id))

func start_combat_node(run_data: Variant, node: Variant, charge_travel_time: bool = true) -> void:
	if run_data == null or node == null:
		push_error("DungeonManager cannot start combat without run data and node data.")
		return
	if not _is_combat_node(node):
		push_error("DungeonManager cannot start combat for non-combat node %s." % node.id)
		return
	if is_node_resolved(run_data, node.id):
		return

	var payload := _combat_payload_for_node(node)
	var payload_error := CombatPayloadValidatorScript.combat_payload_error(payload)
	if not payload_error.is_empty():
		push_error("Dungeon combat node %s has invalid combat payload (%s): %s." % [node.id, payload_error, payload])
		return

	GameManager.start_combat(
		int(payload.get("node_id", -1)),
		str(payload.get("node_type", "")),
		bool(payload.get("is_boss", false)),
		charge_travel_time,
		StringName(payload.get("combat_encounter_id", &"")),
		str(payload.get("combat_encounter_profile_path", "")),
		payload.get("enemy_instances", [])
	)

func get_dungeon_snapshot(run_data: Variant) -> Dictionary:
	if run_data == null:
		return {}

	return {
		"seed": run_data.dungeon_seed,
		"floor_layer": run_data.dungeon_floor_layer,
		"descriptors": run_data.dungeon_node_descriptors.duplicate(true),
		"visited_node_ids": run_data.get_visited_dungeon_node_ids(),
		"revealed_node_ids": run_data.get_revealed_dungeon_node_ids(),
		"resolved_node_ids": run_data.get_resolved_dungeon_node_ids(),
		"active_pawn_ids": run_data.active_dungeon_pawn_ids.duplicate(),
		"pawns": _pawn_snapshots_by_id(run_data),
		"selected_pawn_id": _selected_pawn_id(run_data),
		"current_node_id": current_node_id(run_data),
	}

func _active_difficulty_id() -> StringName:
	var difficulty_service: Variant = get_node_or_null("/root/DifficultyService")
	if difficulty_service == null or not difficulty_service.has_method("get_active_difficulty_id"):
		return &""

	return difficulty_service.get_active_difficulty_id()

func _combat_payload_for_node(node: Variant) -> Dictionary:
	return {
		"node_id": int(node.id),
		"node_type": str(node.node_type),
		"is_boss": bool(node.is_boss) or str(node.node_type) == DungeonNodeDataScript.TYPE_BOSS,
		"combat_encounter_id": node.combat_encounter_id,
		"combat_encounter_profile_path": node.combat_encounter_profile_path,
		"enemy_instances": node.enemy_instances.duplicate(true),
	}

func _is_combat_node(node: Variant) -> bool:
	return node != null and (
		str(node.node_type) == DungeonNodeDataScript.TYPE_FIGHT
		or str(node.node_type) == DungeonNodeDataScript.TYPE_BOSS
	)

func _mark_node_visit_state(run_data: Variant, node_id: int) -> void:
	_add_node_id(run_data.visited_dungeon_node_ids, node_id)
	reveal_node(run_data, node_id)
	reveal_connected_nodes(run_data, node_id)
	run_data.current_node_index = max(int(run_data.current_node_index), node_id)

func _mark_node_resolved(run_data: Variant, node_id: int) -> void:
	_mark_node_visit_state(run_data, node_id)
	_add_node_id(run_data.resolved_dungeon_node_ids, node_id)

func reveal_node(run_data: Variant, node_id: int) -> void:
	if run_data != null:
		_add_node_id(run_data.revealed_dungeon_node_ids, node_id)

func reveal_connected_nodes(run_data: Variant, node_id: int) -> void:
	for connected_id: int in _descriptor_connected_node_ids(run_data, node_id):
		reveal_node(run_data, connected_id)

func unlock_pawns_for_event_node(run_data: Variant, node_id: int) -> void:
	for pawn_id: String in _event_locked_pawn_ids(run_data, node_id):
		var pawn: Variant = get_pawn(run_data, pawn_id)
		if pawn != null:
			pawn.unlock_event()

func _request_single_pawn_travel(run_data: Variant, pawn_id: String, destination_node_id: int) -> Dictionary:
	var pawn: Variant = get_pawn(run_data, pawn_id)
	if pawn == null:
		return _travel_request_result(false, "missing_pawn", [], false)
	if destination_node_id < 0:
		return _travel_request_result(false, "invalid_destination", [], false)
	if int(pawn.current_node_id) == destination_node_id:
		return _travel_request_result(false, "already_at_destination", [], false)
	if bool(pawn.is_locked_by_event) or int(pawn.travel_state) == DungeonMapPawnStateScript.IN_EVENT:
		return _travel_request_result(false, "pawn_locked_by_event", [], false)
	if not bool(pawn.is_active()):
		return _travel_request_result(false, "pawn_inactive", [], false)

	var path: Array[int] = get_pawn_travel_path(run_data, pawn_id, destination_node_id)
	if path.is_empty():
		return _travel_request_result(false, "unreachable_destination", [], false)

	if int(pawn.travel_state) == DungeonMapPawnStateScript.TRAVELING:
		if not ALLOW_DESTINATION_REPLACE_DURING_TRAVEL:
			return _travel_request_result(false, "replacement_disabled", path, false)
		if not pawn.request_destination_replacement(destination_node_id):
			return _travel_request_result(false, "replacement_rejected", path, false)
		return _travel_request_result(true, "", path, true)

	if not pawn.set_travel_order(destination_node_id, path, NODE_TRAVEL_TIME, VISUAL_NODE_STEPS_PER_REAL_SECOND):
		return _travel_request_result(false, "travel_order_rejected", path, false)

	return _travel_request_result(true, "", path, false)

func _request_autopilot_follow_orders(run_data: Variant, leader_pawn_id: String, destination_node_id: int) -> Array[Dictionary]:
	var follow_results: Array[Dictionary] = []
	if not _is_local_leader_pawn_id(run_data, leader_pawn_id):
		return follow_results
	if run_data.player_party_state == null:
		return follow_results

	for member in run_data.player_party_state.get_active_members():
		var party_member: Variant = member
		if party_member == null or not bool(party_member.should_follow_leader()):
			continue

		var follower_pawn_id: String = str(party_member.map_pawn_id)
		if follower_pawn_id.is_empty() or follower_pawn_id == leader_pawn_id:
			continue

		var follower_result: Dictionary = _request_single_pawn_travel(run_data, follower_pawn_id, destination_node_id)
		follow_results.append(_autopilot_follow_result(follower_pawn_id, follower_result))

	return follow_results

func _allowed_path_node_ids(run_data: Variant) -> Array[int]:
	var allowed_node_ids: Array[int] = []
	for node_id: int in run_data.revealed_dungeon_node_ids:
		_add_node_id(allowed_node_ids, node_id)

	for raw_pawn_id in run_data.active_dungeon_pawn_ids:
		var pawn: Variant = get_pawn(run_data, str(raw_pawn_id))
		if pawn != null and bool(pawn.is_active()):
			_add_node_id(allowed_node_ids, int(pawn.current_node_id))

	return allowed_node_ids

func _allowed_path_node_ids_from_snapshot(dungeon_snapshot: Dictionary) -> Array[int]:
	var allowed_node_ids: Array[int] = []
	for raw_node_id in dungeon_snapshot.get("revealed_node_ids", []):
		_add_node_id(allowed_node_ids, int(raw_node_id))

	var pawns: Dictionary = dungeon_snapshot.get("pawns", {})
	for raw_pawn_id in dungeon_snapshot.get("active_pawn_ids", []):
		var pawn: Dictionary = pawns.get(str(raw_pawn_id), {})
		if pawn.is_empty():
			continue
		if int(pawn.get("travel_state", -1)) != DungeonMapPawnStateScript.INACTIVE and int(pawn.get("control_mode", -1)) != PartyControlModeScript.INACTIVE:
			_add_node_id(allowed_node_ids, int(pawn.get("current_node_id", -1)))

	return allowed_node_ids

func _descriptor_connected_node_ids(run_data: Variant, node_id: int) -> Array[int]:
	var connected_ids: Array[int] = []
	var descriptor: Dictionary = _descriptor_for_node_id(run_data, node_id)
	if descriptor.is_empty():
		push_error("Dungeon node %s has no descriptor." % node_id)
		return connected_ids
	if not descriptor.has("connections") or not (descriptor.get("connections") is Array):
		push_error("Dungeon node %s is missing explicit connections." % node_id)
		return connected_ids

	for raw_connected_id in descriptor.get("connections", []):
		var connected_id: int = int(raw_connected_id)
		if connected_id >= 0:
			_add_node_id(connected_ids, connected_id)

	return connected_ids

func _descriptor_for_node_id(run_data: Variant, node_id: int) -> Dictionary:
	if run_data == null:
		return {}

	for raw_descriptor in run_data.dungeon_node_descriptors:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		if int(descriptor.get("id", -1)) == node_id:
			return descriptor

	return {}

func _completion_pawn_ids_for_node(run_data: Variant, node_id: int, pawn_id: String = "") -> Array[String]:
	var completion_pawn_ids: Array[String] = []
	if not pawn_id.is_empty() and get_pawn(run_data, pawn_id) != null:
		_add_pawn_id(completion_pawn_ids, pawn_id)

	for locked_pawn_id: String in _event_locked_pawn_ids(run_data, node_id):
		_add_pawn_id(completion_pawn_ids, locked_pawn_id)

	return completion_pawn_ids

func _event_locked_pawn_ids(run_data: Variant, node_id: int) -> Array[String]:
	var locked_pawn_ids: Array[String] = []
	if run_data == null or node_id < 0:
		return locked_pawn_ids

	for raw_pawn in run_data.dungeon_map_pawns.values():
		var pawn: Variant = raw_pawn
		if pawn != null and bool(pawn.is_locked_by_event) and int(pawn.active_event_node_id) == node_id:
			_add_pawn_id(locked_pawn_ids, str(pawn.pawn_id))

	return locked_pawn_ids

func _sync_current_pawn_node(run_data: Variant, node_id: int, pawn_id: String = "") -> bool:
	var pawn: Variant = null
	if not pawn_id.is_empty():
		pawn = get_pawn(run_data, pawn_id)
		if pawn == null:
			return false
	else:
		pawn = get_selected_pawn(run_data)
	if pawn == null:
		return false

	pawn.set_current_node_id(node_id)
	if _is_selected_pawn_id(run_data, str(pawn.pawn_id)):
		run_data.current_dungeon_node_id = node_id
	return true

func _is_selected_pawn_id(run_data: Variant, pawn_id: String) -> bool:
	if pawn_id.is_empty():
		return false

	var selected_pawn: Variant = get_selected_pawn(run_data)
	return selected_pawn != null and str(selected_pawn.pawn_id) == pawn_id

func _is_local_leader_pawn_id(run_data: Variant, pawn_id: String) -> bool:
	var member: Variant = _party_member_for_pawn_id(run_data, pawn_id)
	if member == null or run_data.player_party_state == null:
		return false
	if str(member.party_member_id) != str(run_data.player_party_state.leader_member_id):
		return false

	return bool(member.is_unlocked) \
		and bool(member.is_active) \
		and int(member.control_mode) == PartyControlModeScript.LOCAL_PLAYER

func _party_member_for_pawn_id(run_data: Variant, pawn_id: String) -> Variant:
	if run_data == null or run_data.player_party_state == null or pawn_id.is_empty():
		return null

	for raw_member in run_data.player_party_state.members.values():
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

func _travel_request_result(accepted: bool, reason: String, path: Array, queued_replacement: bool) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"path": path.duplicate(),
		"queued_replacement": queued_replacement,
	}

func _pawn_snapshots_by_id(run_data: Variant) -> Dictionary:
	var snapshots: Dictionary = {}
	for raw_pawn_id in run_data.active_dungeon_pawn_ids:
		var pawn_id: String = str(raw_pawn_id)
		var pawn: Variant = get_pawn(run_data, pawn_id)
		if pawn != null:
			snapshots[pawn_id] = _pawn_snapshot(pawn)
	return snapshots

func _selected_pawn_id(run_data: Variant) -> String:
	var pawn: Variant = get_selected_pawn(run_data)
	return str(pawn.pawn_id) if pawn != null else ""

func _pawn_snapshot(pawn: Variant) -> Dictionary:
	return {
		"pawn_id": str(pawn.pawn_id),
		"party_member_id": str(pawn.party_member_id),
		"combatant_id": str(pawn.combatant_id),
		"owner_player_id": str(pawn.owner_player_id),
		"control_mode": int(pawn.control_mode),
		"current_node_id": int(pawn.current_node_id),
		"destination_node_id": int(pawn.destination_node_id),
		"travel_state": int(pawn.travel_state),
		"travel_state_id": str(pawn.travel_state_id()),
		"is_locked_by_event": bool(pawn.is_locked_by_event),
		"active_event_node_id": int(pawn.active_event_node_id),
	}

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
	var normalized: String = party_member_id.strip_edges().to_lower().replace(" ", "_")
	if normalized.begins_with("party_member."):
		normalized = normalized.substr("party_member.".length())
	if normalized.is_empty():
		normalized = "member"

	return "map_pawn.%s" % normalized

func _party_manager() -> Variant:
	return get_node_or_null("/root/PartyManager")
