## Stores mutable run state only; gameplay decisions live in managers and services.
class_name RunData
extends RefCounted

const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"
const DEFAULT_CHARACTER := "Warrior"
const DEFAULT_DIFFICULTY := "normal"
const DEFAULT_RUN_TIME_SECONDS := 1000.0
const START_DUNGEON_NODE_ID := 0

var selected_character: String = DEFAULT_CHARACTER
var dungeon_seed: String = ""
var dungeon_floor_layer: int = 1
var dungeon_node_descriptors: Array = []
var dungeon_map_pawns: Dictionary = {}
var active_dungeon_pawn_ids: Array[String] = []
var revealed_dungeon_node_ids: Array[int] = []
var resolved_dungeon_node_ids: Array[int] = []
var visited_dungeon_node_ids: Array[int] = []
var active_dungeon_event: Dictionary = {}

var max_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var remaining_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var time_elapsed: float = 0.0
var gold: int = 0
var memories: int = 0
var run_end_reason: String = END_REASON_IN_PROGRESS
var memories_exported: bool = false
var player_party_state: Variant = null
var run_stat_modifiers: Array[Dictionary] = []

var current_node_index: int = 0
var current_dungeon_node_id: int = -1
var total_nodes: int = 5
var boss_node_index: int = 4

var fights_completed: int = 0
var regular_fights_completed: int = 0
var boss_defeated: bool = false
var damage_dealt: int = 0
var damage_taken: int = 0
var actions_used: int = 0
var run_victory: bool = false

func configure_selection(character: String) -> void:
	selected_character = character if not character.is_empty() else DEFAULT_CHARACTER

## Resets state for a new run without generating gameplay content.
func start_run(
	character: String,
	run_time_seconds: float,
	new_dungeon_seed: String = "",
	new_dungeon_floor_layer: int = 1
) -> void:
	configure_selection(character)
	dungeon_seed = new_dungeon_seed.strip_edges()
	dungeon_floor_layer = max(new_dungeon_floor_layer, 1)
	dungeon_node_descriptors.clear()
	dungeon_map_pawns.clear()
	active_dungeon_pawn_ids.clear()
	revealed_dungeon_node_ids.clear()
	resolved_dungeon_node_ids.clear()
	visited_dungeon_node_ids.clear()
	active_dungeon_event.clear()
	gold = 0
	memories = 0
	run_end_reason = END_REASON_IN_PROGRESS
	memories_exported = false
	player_party_state = null
	run_stat_modifiers.clear()
	current_node_index = 0
	current_dungeon_node_id = -1
	total_nodes = 5
	boss_node_index = 4
	fights_completed = 0
	regular_fights_completed = 0
	boss_defeated = false
	damage_dealt = 0
	damage_taken = 0
	actions_used = 0
	run_victory = false
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
	return applied_seconds

func add_currencies(new_memories: int, new_gold: int) -> void:
	memories += max(new_memories, 0)
	gold += max(new_gold, 0)

func spend_memories(amount: int) -> bool:
	var cost: int = max(amount, 0)
	if cost <= 0:
		return true
	if memories < cost:
		return false
	memories -= cost
	return true

func end_run(reason: String) -> void:
	if reason.is_empty():
		reason = END_REASON_DEFEAT

	run_end_reason = reason
	run_victory = reason == END_REASON_VICTORY

func has_ended() -> bool:
	return run_end_reason != END_REASON_IN_PROGRESS

func has_dungeon_map_pawns() -> bool:
	return not dungeon_map_pawns.is_empty()

func get_dungeon_map_pawn(pawn_id: String) -> Variant:
	return dungeon_map_pawns.get(pawn_id, null)

func get_visited_dungeon_node_ids() -> Array[int]:
	return visited_dungeon_node_ids.duplicate()

func get_revealed_dungeon_node_ids() -> Array[int]:
	return revealed_dungeon_node_ids.duplicate()

func get_resolved_dungeon_node_ids() -> Array[int]:
	return resolved_dungeon_node_ids.duplicate()
