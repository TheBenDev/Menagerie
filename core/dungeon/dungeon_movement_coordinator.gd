## Advances active dungeon pawn travel orders in synchronized node steps.
class_name DungeonMovementCoordinator
extends RefCounted

const RESULT_MOVED_PAWN_IDS := "moved_pawn_ids"
const RESULT_PAUSE_REQUESTED := "pause_requested"
const RESULT_PAUSE_REASONS := "pause_reasons"
const RESULT_REACHED_DESTINATION_IDS := "reached_destination_pawn_ids"
const RESULT_INTERRUPTED_PAWN_IDS := "interrupted_pawn_ids"
const RESULT_CANCELLED_PAWN_IDS := "cancelled_pawn_ids"
const RESULT_REPLACED_PAWN_IDS := "replaced_pawn_ids"

## Returns true when at least one active pawn has a travel order ready to advance.
static func has_active_travel_orders(run_data: Variant) -> bool:
	if run_data == null:
		return false

	for pawn_id in run_data.active_dungeon_pawn_ids:
		var pawn: Variant = run_data.get_dungeon_map_pawn(str(pawn_id))
		if pawn != null and pawn.has_active_travel_order() and pawn.next_path_node_id() >= 0:
			return true

	return false

## Advances every active traveling pawn by one node step and reports whether movement should pause.
static func advance_one_step(run_data: Variant, interrupt_node_ids: Array = []) -> Dictionary:
	var result: Dictionary = _empty_result()
	if run_data == null:
		result[RESULT_PAUSE_REQUESTED] = true
		result[RESULT_PAUSE_REASONS].append("missing_run_data")
		return result

	var moving_pawns: Array = _active_moving_pawns(run_data)
	if moving_pawns.is_empty():
		result[RESULT_PAUSE_REQUESTED] = true
		result[RESULT_PAUSE_REASONS].append("no_active_travel_orders")
		return result

	var interrupt_lookup: Dictionary = _int_lookup(interrupt_node_ids)
	for pawn in moving_pawns:
		var map_pawn: Variant = pawn
		var pawn_id: String = str(map_pawn.pawn_id)
		var next_node_id: int = int(map_pawn.next_path_node_id())
		if next_node_id < 0:
			map_pawn.clear_travel()
			_append_result_id(result, RESULT_INTERRUPTED_PAWN_IDS, pawn_id)
			_append_pause_reason(result, "invalid_next_node")
			continue

		run_data.move_dungeon_pawn_to_node(pawn_id, next_node_id)
		map_pawn.travel_path_index += 1
		_append_result_id(result, RESULT_MOVED_PAWN_IDS, pawn_id)

		if _handle_post_step_state(run_data, map_pawn, interrupt_lookup, result):
			result[RESULT_PAUSE_REQUESTED] = true

	return result

static func _handle_post_step_state(
	run_data: Variant,
	pawn: Variant,
	interrupt_lookup: Dictionary,
	result: Dictionary
) -> bool:
	var pawn_id: String = str(pawn.pawn_id)
	var current_node_id: int = int(pawn.current_node_id)
	if bool(pawn.cancel_requested):
		pawn.clear_travel()
		_append_result_id(result, RESULT_CANCELLED_PAWN_IDS, pawn_id)
		_append_pause_reason(result, "cancelled")
		return true

	if interrupt_lookup.has(current_node_id):
		pawn.clear_travel()
		_append_result_id(result, RESULT_INTERRUPTED_PAWN_IDS, pawn_id)
		_append_pause_reason(result, "event_node")
		return true

	if int(pawn.pending_destination_node_id) >= 0:
		var replacement_destination_id: int = int(pawn.pending_destination_node_id)
		pawn.pending_destination_node_id = -1
		var replacement_path: Array[int] = run_data.get_dungeon_pawn_travel_path(pawn_id, replacement_destination_id)
		if replacement_path.is_empty():
			pawn.clear_travel()
			_append_result_id(result, RESULT_INTERRUPTED_PAWN_IDS, pawn_id)
			_append_pause_reason(result, "replacement_unreachable")
			return true

		if pawn.set_travel_order(
			replacement_destination_id,
			replacement_path,
			RunData.NODE_STEP_DUNGEON_TIME_SECONDS,
			RunData.VISUAL_NODE_STEPS_PER_REAL_SECOND
		):
			_append_result_id(result, RESULT_REPLACED_PAWN_IDS, pawn_id)
			return false

		pawn.clear_travel()
		_append_result_id(result, RESULT_INTERRUPTED_PAWN_IDS, pawn_id)
		_append_pause_reason(result, "replacement_rejected")
		return true

	if current_node_id == int(pawn.destination_node_id) or pawn.travel_path_index >= pawn.travel_path.size() - 1:
		pawn.clear_travel()
		_append_result_id(result, RESULT_REACHED_DESTINATION_IDS, pawn_id)
		_append_pause_reason(result, "destination_reached")
		return true

	return false

static func _active_moving_pawns(run_data: Variant) -> Array:
	var moving_pawns: Array = []
	for pawn_id in run_data.active_dungeon_pawn_ids:
		var pawn: Variant = run_data.get_dungeon_map_pawn(str(pawn_id))
		if pawn != null and pawn.has_active_travel_order() and pawn.next_path_node_id() >= 0:
			moving_pawns.append(pawn)

	return moving_pawns

static func _empty_result() -> Dictionary:
	return {
		RESULT_MOVED_PAWN_IDS: [],
		RESULT_PAUSE_REQUESTED: false,
		RESULT_PAUSE_REASONS: [],
		RESULT_REACHED_DESTINATION_IDS: [],
		RESULT_INTERRUPTED_PAWN_IDS: [],
		RESULT_CANCELLED_PAWN_IDS: [],
		RESULT_REPLACED_PAWN_IDS: [],
	}

static func _append_result_id(result: Dictionary, key: String, pawn_id: String) -> void:
	var ids: Array = result.get(key, [])
	if not ids.has(pawn_id):
		ids.append(pawn_id)
	result[key] = ids

static func _append_pause_reason(result: Dictionary, reason: String) -> void:
	var reasons: Array = result.get(RESULT_PAUSE_REASONS, [])
	if not reasons.has(reason):
		reasons.append(reason)
	result[RESULT_PAUSE_REASONS] = reasons

static func _int_lookup(values: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for value in values:
		lookup[int(value)] = true

	return lookup
