class_name RunData
extends RefCounted

const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"
const DEFAULT_CHARACTER := "Warrior"
const DEFAULT_DIFFICULTY := "normal"
const DEFAULT_RUN_TIME_SECONDS := 500.0
const NODE_TRAVEL_TIME_SECONDS := 30.0

var selected_character: String = DEFAULT_CHARACTER
var selected_difficulty: String = DEFAULT_DIFFICULTY

var max_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var remaining_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var gold: int = 0
var memories: int = 0
var run_end_reason: String = END_REASON_IN_PROGRESS
var memories_exported: bool = false

var current_node_index: int = 0
var total_nodes: int = 5
var boss_node_index: int = 4

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

func start_run(character: String, difficulty: String, run_time_seconds: float, default_enemy_profile_path: String) -> void:
	configure_selection(character, difficulty)
	gold = 0
	memories = 0
	run_end_reason = END_REASON_IN_PROGRESS
	memories_exported = false
	pending_combat_result = null
	current_node_index = 0
	total_nodes = 5
	boss_node_index = 4
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

	if not result.victory:
		end_run(result.end_reason if not str(result.end_reason).is_empty() else END_REASON_DEFEAT)
		return

	grant_rewards(result.memories_awarded, result.gold_awarded)
	fights_completed += 1
	current_node_index = max(current_node_index, result.node_id)

	if result.is_boss:
		boss_defeated = true
		end_run(END_REASON_VICTORY)
	else:
		regular_fights_completed += 1
