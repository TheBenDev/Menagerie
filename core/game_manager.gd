## Autoload that coordinates top-level run setup, scene transitions, run timers, and subsystem delegation.
extends Node

const RunDataScript := preload("res://core/run_data.gd")
const CombatPayloadValidatorScript := preload("res://core/combat/combat_payload_validator.gd")
const RewardServiceScript := preload("res://core/rewards/reward_service.gd")
const SceneRouteServiceScript := preload("res://core/scene_route_service.gd")
const DEFAULT_DUNGEON_GENERATION_CONFIG := preload("res://core/dungeon/default_dungeon_floor_generation_config.tres")
const DEFAULT_DUNGEON_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_encounter_pool.tres")
const DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres")
const DEFAULT_DUNGEON_ABILITY_POOL := preload("res://core/dungeon/abilities/default_dungeon_ability_pool.tres")

signal run_time_changed(remaining_time_seconds: float, max_time_seconds: float)
signal run_currencies_changed(memories: int, gold: int)
signal run_ended(reason: String)

var current_run_data = null
var selected_setup_character: String = RunDataScript.DEFAULT_CHARACTER
var setup_dungeon_seed: String = ""
var setup_dungeon_floor_layer: int = 1
var pending_class_memory_awards: Dictionary = {}

func _ready() -> void:
	call_deferred("_play_music_for_current_scene")

func start_new_run(character: String, difficulty: String, dungeon_seed: String = "", dungeon_floor_layer: int = 1) -> Variant:
	var difficulty_id := StringName(difficulty.strip_edges().to_lower())
	DifficultyService.set_active_difficulty_id(difficulty_id)
	current_run_data = RunDataScript.new()
	current_run_data.start_run(
		character,
		RunDataScript.DEFAULT_RUN_TIME_SECONDS,
		_resolve_dungeon_seed(dungeon_seed),
		max(dungeon_floor_layer, 1)
	)
	PartyManager.initialize_party_for_run(current_run_data, StringName(character))
	_apply_run_seed(current_run_data.dungeon_seed)
	DungeonManager.initialize_dungeon_for_run(current_run_data)
	if current_run_data.dungeon_node_descriptors.is_empty():
		push_error("New run could not start because dungeon generation produced no valid descriptors.")
		clear_run()
		return null
	selected_setup_character = current_run_data.selected_character
	setup_dungeon_seed = current_run_data.dungeon_seed
	setup_dungeon_floor_layer = current_run_data.dungeon_floor_layer
	emit_run_state()
	MusicDirector.on_run_started()
	return current_run_data

func clear_run() -> void:
	current_run_data = null

func start_combat(
	node_id: int,
	node_type: String,
	is_boss: bool,
	charge_travel_time: bool = true,
	combat_encounter_id: StringName = &"",
	combat_encounter_profile_path: String = "",
	enemy_instances: Array[Dictionary] = []
) -> void:
	if current_run_data == null:
		push_error("Combat cannot start without an active run.")
		return
	if not _validate_combat_payload(node_id, combat_encounter_id, enemy_instances):
		return

	if charge_travel_time and not advance_run_time(DungeonManager.NODE_TRAVEL_TIME):
		return

	CombatManager.start_combat_from_dungeon(current_run_data, node_id, {
		"node_type": node_type,
		"is_boss": is_boss,
		"combat_encounter_id": combat_encounter_id,
		"combat_encounter_profile_path": combat_encounter_profile_path,
		"enemy_instances": enemy_instances,
	})

	MusicDirector.on_combat_started({"is_boss": is_boss})
	go_to_scene("combat/BattleScene")

func complete_combat(result: Variant) -> void:
	if _is_run_ended():
		return

	if result != null:
		CombatManager.complete_combat(result)
	go_to_scene("dungeon")

func consume_last_combat_result() -> Variant:
	if current_run_data == null:
		return null

	return CombatManager.consume_pending_combat_result()

func has_pending_combat_result() -> bool:
	return CombatManager.has_pending_combat_result()

func advance_run_time(seconds: float) -> bool:
	if current_run_data == null:
		return true
	if _is_run_ended():
		return false

	var applied_seconds: float = current_run_data.advance_time(seconds)
	PartyManager.advance_run_effects(current_run_data, applied_seconds)
	emit_run_state()

	if current_run_data.remaining_run_time_seconds <= 0.0:
		end_current_run(RunDataScript.END_REASON_TIMEOUT)
		return false

	return true

func get_dungeon_encounter(encounter_id: StringName) -> Resource:
	return DungeonManager.get_dungeon_encounter(encounter_id)

func get_dungeon_encounter_scene(encounter_id: StringName) -> PackedScene:
	return DungeonManager.get_dungeon_encounter_scene(encounter_id)

func get_dungeon_combat_encounter(encounter_id: StringName) -> Resource:
	return DungeonManager.get_dungeon_combat_encounter(encounter_id)

func get_dungeon_abilities(slot_count: int = 3) -> Array:
	return DungeonManager.get_dungeon_abilities(slot_count)

func apply_dungeon_encounter_result(encounter_id: StringName, result: Dictionary) -> Dictionary:
	var outcome := {
		"handled": false,
		"damage_taken": 0,
		"stat_modifiers_added": 0,
	}
	if current_run_data == null or _is_run_ended():
		return outcome

	var manager_result := result.duplicate(true)
	manager_result["encounter_id"] = encounter_id
	outcome = DungeonManager.apply_encounter_result(current_run_data, manager_result)
	emit_run_state()

	if PartyManager.is_player_defeated(current_run_data):
		end_current_run(RunDataScript.END_REASON_DEFEAT)

	return outcome

func apply_run_player_state_to_combatant(combatant: Variant) -> void:
	PartyManager.apply_member_state_to_combatant(current_run_data, combatant)

func get_run_player_hp_snapshot() -> Dictionary:
	return PartyManager.get_selected_member_hp_snapshot(current_run_data)

func get_selected_player_combatant_id() -> String:
	return PartyManager.get_selected_combatant_id(current_run_data)

func get_effective_player_stats() -> Dictionary:
	return PartyManager.get_selected_member_effective_stats(current_run_data)

func end_current_run(reason: String) -> void:
	if current_run_data == null or _is_run_ended():
		return

	current_run_data.end_run(reason)
	emit_run_state()
	run_ended.emit(reason)
	call_deferred("go_to_scene", "run_summary")

func emit_run_state() -> void:
	if current_run_data == null:
		run_time_changed.emit(0.0, RunDataScript.DEFAULT_RUN_TIME_SECONDS)
		run_currencies_changed.emit(0, 0)
		return

	run_time_changed.emit(current_run_data.remaining_run_time_seconds, current_run_data.max_run_time_seconds)
	run_currencies_changed.emit(current_run_data.memories, current_run_data.gold)

func export_current_run_memories() -> int:
	if current_run_data == null:
		return 0

	return RewardServiceScript.export_run_memories_to_class_awards(current_run_data, pending_class_memory_awards)

func get_selected_difficulty_profile() -> Resource:
	return DifficultyService.get_active_profile()

func get_selected_character_profile() -> CombatantProfile:
	return PartyManager.get_character_profile(get_selected_character_id()) as CombatantProfile

func get_selected_character_profile_path() -> String:
	return PartyManager.get_character_profile_path(get_selected_character_id())

func get_selected_character_id() -> String:
	if current_run_data != null:
		return current_run_data.selected_character

	return selected_setup_character

func get_selected_difficulty_id() -> String:
	return String(DifficultyService.get_active_difficulty_id())

func get_selected_difficulty_profile_path() -> String:
	return DifficultyService.get_profile_path(StringName(get_selected_difficulty_id()))

func get_selected_difficulty_display_name() -> String:
	return DifficultyService.get_active_display_name()

func has_active_run() -> bool:
	return current_run_data != null and not _is_run_ended()

func has_current_run_data() -> bool:
	return current_run_data != null

## Temporary action boundary for scene controllers; display/UI code must use snapshots instead.
func get_current_run_reference() -> Variant:
	return current_run_data

func get_timer_snapshot() -> Dictionary:
	if current_run_data == null:
		return {
			"remaining_time_seconds": 0.0,
			"max_time_seconds": RunDataScript.DEFAULT_RUN_TIME_SECONDS,
		}

	return {
		"remaining_time_seconds": current_run_data.remaining_run_time_seconds,
		"max_time_seconds": current_run_data.max_run_time_seconds,
	}

func get_currency_snapshot() -> Dictionary:
	if current_run_data == null:
		return {
			"memories": 0,
			"gold": 0,
		}

	return {
		"memories": max(int(current_run_data.memories), 0),
		"gold": max(int(current_run_data.gold), 0),
	}

func get_run_summary_snapshot() -> Dictionary:
	if current_run_data == null:
		return {}

	return {
		"character": current_run_data.selected_character,
		"difficulty": get_selected_difficulty_display_name(),
		"fights_completed": current_run_data.fights_completed,
		"boss_defeated": current_run_data.boss_defeated,
		"damage_dealt": current_run_data.damage_dealt,
		"damage_taken": current_run_data.damage_taken,
		"actions_used": current_run_data.actions_used,
		"time_elapsed": current_run_data.time_elapsed,
		"memories": current_run_data.memories,
		"gold": current_run_data.gold,
		"run_end_reason": current_run_data.run_end_reason,
		"run_victory": current_run_data.run_victory,
	}

func get_party_snapshot() -> Dictionary:
	return PartyManager.get_party_snapshot(current_run_data)

func get_dungeon_snapshot() -> Dictionary:
	return DungeonManager.get_dungeon_snapshot(current_run_data)

func get_combat_snapshot() -> Dictionary:
	return CombatManager.get_combat_snapshot()

func go_to_scene(scene_ref: String) -> void:
	var scene_path := scene_path_for(scene_ref)
	if scene_path.is_empty():
		push_error("Failed to change scene: scene reference is empty.")
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s. Error: %s" % [scene_path, error])
		return

func play_music_for_scene(scene_ref: String) -> void:
	_play_music_for_scene_path(scene_path_for(scene_ref))

func play_run_music(restart: bool = false) -> void:
	MusicDirector.on_dungeon_entered({"restart": restart})

func scene_path_for(scene_ref: String) -> String:
	return SceneRouteServiceScript.scene_path_for(scene_ref)

func _play_music_for_current_scene() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	_play_music_for_scene_path(current_scene.scene_file_path)

func _play_music_for_scene_path(scene_path: String) -> void:
	MusicDirector.on_route_changed(StringName(scene_path))

func _resolve_dungeon_seed(requested_seed: String) -> String:
	var requested_seed_text := requested_seed.strip_edges()
	if not requested_seed_text.is_empty():
		return requested_seed_text

	return "run_%s_%s" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]

func _apply_run_seed(run_seed: String) -> void:
	seed(run_seed.hash())

func _is_run_ended() -> bool:
	return current_run_data != null and current_run_data.has_ended()

func _validate_combat_payload(node_id: int, combat_encounter_id: StringName, enemy_instances: Array[Dictionary]) -> bool:
	var payload := {
		"node_id": node_id,
		"combat_encounter_id": combat_encounter_id,
		"enemy_instances": enemy_instances,
	}
	var payload_error := CombatPayloadValidatorScript.combat_payload_error(payload)
	if not payload_error.is_empty():
		push_error("Combat cannot start with invalid payload (%s): %s." % [payload_error, payload])
		return false

	return true
