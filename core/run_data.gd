## Stores all mutable state for a run, including selection, timer, encounters, rewards, and combat totals.
class_name RunData
extends RefCounted

const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"
const DEFAULT_CHARACTER := "Warrior"
const DEFAULT_DIFFICULTY := "normal"
const DEFAULT_RUN_TIME_SECONDS := 1000.0
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

var max_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var remaining_run_time_seconds: float = DEFAULT_RUN_TIME_SECONDS
var gold: int = 0
var memories: int = 0
var run_end_reason: String = END_REASON_IN_PROGRESS
var memories_exported: bool = false
var player_base_stats: Dictionary = {}
var player_current_hp: int = 0
var player_max_hp: int = 0
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
	gold = 0
	memories = 0
	run_end_reason = END_REASON_IN_PROGRESS
	memories_exported = false
	player_base_stats.clear()
	player_current_hp = 0
	player_max_hp = 0
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

func initialize_player_state(profile: Resource) -> void:
	player_base_stats = {
		STAT_STRENGTH: _profile_stat(profile, "strength", 5),
		STAT_DEXTERITY: _profile_stat(profile, "dexterity", 5),
		STAT_INTELLIGENCE: _profile_stat(profile, "intelligence", 5),
		STAT_VITALITY: _profile_stat(profile, "vitality", 5),
	}
	_recalculate_player_max_hp(true)

func get_effective_stats() -> Dictionary:
	return {
		STAT_STRENGTH: get_effective_stat(STAT_STRENGTH),
		STAT_DEXTERITY: get_effective_stat(STAT_DEXTERITY),
		STAT_INTELLIGENCE: get_effective_stat(STAT_INTELLIGENCE),
		STAT_VITALITY: get_effective_stat(STAT_VITALITY),
	}

func get_effective_stat(stat_id: String) -> int:
	var canonical_stat_id := _canonical_stat_id(stat_id)
	var value := int(player_base_stats.get(canonical_stat_id, 0))
	for modifier in run_stat_modifiers:
		if str(modifier.get("stat_id", "")) == canonical_stat_id:
			value += int(modifier.get("amount", 0))

	return max(value, 0)

func apply_player_stats_to_combatant(combatant: Variant) -> void:
	if combatant == null:
		return

	combatant.strength = get_effective_stat(STAT_STRENGTH)
	combatant.dexterity = get_effective_stat(STAT_DEXTERITY)
	combatant.intelligence = get_effective_stat(STAT_INTELLIGENCE)
	combatant.vitality = get_effective_stat(STAT_VITALITY)

func set_player_hp_from_combat(current_hp: int) -> void:
	player_current_hp = clamp(current_hp, 0, max(player_max_hp, 1))

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
			player_current_hp = max(player_current_hp - max(amount, 0), 0)
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

func mark_dungeon_node_visited(node_id: int) -> void:
	if node_id < 0:
		return

	if not visited_dungeon_node_ids.has(node_id):
		visited_dungeon_node_ids.append(node_id)
		visited_dungeon_node_ids.sort()

	current_node_index = max(current_node_index, node_id)
	current_dungeon_node_id = node_id

func is_dungeon_node_visited(node_id: int) -> bool:
	return visited_dungeon_node_ids.has(node_id)

func get_visited_dungeon_node_ids() -> Array[int]:
	return visited_dungeon_node_ids.duplicate()

func get_last_visited_dungeon_node_id() -> int:
	if current_dungeon_node_id >= 0:
		return current_dungeon_node_id

	if visited_dungeon_node_ids.is_empty():
		return -1

	return int(visited_dungeon_node_ids[visited_dungeon_node_ids.size() - 1])

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
		set_player_hp_from_combat(int(player_hp_after))

	if not result.victory:
		end_run(result.end_reason if not str(result.end_reason).is_empty() else END_REASON_DEFEAT)
		return

	grant_rewards(result.memories_awarded, result.gold_awarded)
	fights_completed += 1
	mark_dungeon_node_visited(result.node_id)

	if result.is_boss:
		boss_defeated = true
		end_run(END_REASON_VICTORY)
	else:
		regular_fights_completed += 1

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
	_recalculate_player_max_hp(false)

func _recalculate_player_max_hp(heal_to_full: bool) -> void:
	player_max_hp = max(get_effective_stat(STAT_VITALITY), 1) * 10
	if heal_to_full:
		player_current_hp = player_max_hp
	else:
		player_current_hp = clamp(player_current_hp, 0, player_max_hp)

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
