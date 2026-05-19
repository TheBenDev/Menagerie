## Stores one party member's authoritative dungeon map position and travel/event state.
class_name DungeonMapPawnState
extends RefCounted

const PartyControlModeScript := preload("res://core/party/party_control_mode.gd")

enum TravelState {
	IDLE,
	TRAVELING,
	IN_EVENT,
	INACTIVE,
}

const IDLE := TravelState.IDLE
const TRAVELING := TravelState.TRAVELING
const IN_EVENT := TravelState.IN_EVENT
const INACTIVE := TravelState.INACTIVE

const IDLE_ID := "Idle"
const TRAVELING_ID := "Traveling"
const IN_EVENT_ID := "InEvent"
const INACTIVE_ID := "Inactive"

var pawn_id: String = ""
var party_member_id: String = ""
var combatant_id: String = ""
var owner_peer_id: int = 1
var control_mode: int = PartyControlModeScript.LOCAL_PLAYER
var current_node_id: int = -1
var travel_origin_node_id: int = -1
var destination_node_id: int = -1
var travel_path: Array[int] = []
var travel_path_index: int = 0
var travel_state: int = IDLE
var pending_destination_node_id: int = -1
var step_game_cost_seconds: float = 1.0
var visual_steps_per_second: float = 4.0
var cancel_requested: bool = false
var is_locked_by_event: bool = false
var active_event_node_id: int = -1

func _init(
	new_pawn_id: String = "",
	new_party_member_id: String = "",
	new_combatant_id: String = "",
	new_owner_peer_id: int = 1,
	new_control_mode: int = PartyControlModeScript.LOCAL_PLAYER,
	new_current_node_id: int = -1
) -> void:
	pawn_id = new_pawn_id
	party_member_id = new_party_member_id
	combatant_id = new_combatant_id
	owner_peer_id = max(new_owner_peer_id, 1)
	control_mode = new_control_mode
	set_current_node_id(new_current_node_id)

## Copies identity and control data from a player party member into this pawn.
func configure_for_party_member(
	new_pawn_id: String,
	member: Variant,
	start_node_id: int
) -> void:
	pawn_id = new_pawn_id.strip_edges()
	party_member_id = str(member.party_member_id) if member != null else ""
	combatant_id = _combatant_id_from_member(member)
	owner_peer_id = max(int(member.owner_peer_id), 1) if member != null else 1
	control_mode = int(member.control_mode) if member != null else PartyControlModeScript.INACTIVE
	set_current_node_id(start_node_id)
	clear_travel()
	is_locked_by_event = false
	active_event_node_id = -1
	travel_state = INACTIVE if control_mode == PartyControlModeScript.INACTIVE else IDLE

## Updates the pawn's authoritative node position.
func set_current_node_id(node_id: int) -> void:
	current_node_id = node_id

## Assigns a path-based travel order without advancing the pawn yet.
func set_travel_order(
	new_destination_node_id: int,
	new_travel_path: Array,
	new_step_game_cost_seconds: float,
	new_visual_steps_per_second: float
) -> bool:
	if new_destination_node_id < 0 or new_travel_path.size() < 2 or is_locked_by_event:
		return false
	if control_mode == PartyControlModeScript.INACTIVE:
		return false

	var normalized_path: Array[int] = _normalized_path(new_travel_path)
	if normalized_path.size() < 2 or normalized_path.front() != current_node_id or normalized_path.back() != new_destination_node_id:
		return false

	travel_origin_node_id = current_node_id
	destination_node_id = new_destination_node_id
	travel_path = normalized_path
	travel_path_index = 0
	pending_destination_node_id = -1
	step_game_cost_seconds = max(new_step_game_cost_seconds, 0.0)
	visual_steps_per_second = max(new_visual_steps_per_second, 0.01)
	cancel_requested = false
	travel_state = TRAVELING
	return true

## Clears path-related fields without changing current position.
func clear_travel() -> void:
	travel_origin_node_id = -1
	destination_node_id = -1
	travel_path.clear()
	travel_path_index = 0
	pending_destination_node_id = -1
	cancel_requested = false
	if not is_locked_by_event:
		travel_state = INACTIVE if control_mode == PartyControlModeScript.INACTIVE else IDLE

## Queues a destination replacement to be handled after the current movement step.
func request_destination_replacement(new_destination_node_id: int) -> bool:
	if new_destination_node_id < 0 or travel_state != TRAVELING or is_locked_by_event:
		return false

	pending_destination_node_id = new_destination_node_id
	return true

## Requests cancellation once the current node step finishes.
func request_cancel_after_current_step() -> bool:
	if travel_state != TRAVELING:
		return false

	cancel_requested = true
	return true

func has_active_travel_order() -> bool:
	return travel_state == TRAVELING and travel_path.size() >= 2

func next_path_node_id() -> int:
	if not has_active_travel_order():
		return -1

	var next_index: int = travel_path_index + 1
	if next_index < 0 or next_index >= travel_path.size():
		return -1

	return int(travel_path[next_index])

## Marks this pawn as participating in an unresolved dungeon event.
func lock_for_event(node_id: int) -> void:
	is_locked_by_event = true
	active_event_node_id = node_id
	destination_node_id = -1
	travel_path.clear()
	travel_path_index = 0
	pending_destination_node_id = -1
	travel_state = IN_EVENT

## Clears event lock state after the active event has resolved.
func unlock_event() -> void:
	is_locked_by_event = false
	active_event_node_id = -1
	travel_state = INACTIVE if control_mode == PartyControlModeScript.INACTIVE else IDLE

func is_idle() -> bool:
	return travel_state == IDLE

func is_active() -> bool:
	return travel_state != INACTIVE and control_mode != PartyControlModeScript.INACTIVE

func travel_state_id() -> String:
	match travel_state:
		IDLE:
			return IDLE_ID
		TRAVELING:
			return TRAVELING_ID
		IN_EVENT:
			return IN_EVENT_ID
		INACTIVE:
			return INACTIVE_ID
		_:
			return IDLE_ID

static func _combatant_id_from_member(member: Variant) -> String:
	if member == null or member.combatant_state == null:
		return ""

	return str(member.combatant_state.combatant_id)

static func _normalized_path(raw_path: Array) -> Array[int]:
	var normalized_path: Array[int] = []
	for raw_node_id in raw_path:
		normalized_path.append(int(raw_node_id))

	return normalized_path
