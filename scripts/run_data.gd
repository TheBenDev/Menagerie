class_name RunData
extends RefCounted

const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"

var selected_character: String = "Warrior"
var selected_difficulty: String = "normal"

var max_run_time_seconds: float = 300.0
var remaining_run_time_seconds: float = 300.0
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
