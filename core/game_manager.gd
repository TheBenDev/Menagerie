## Autoload that coordinates run setup, scene transitions, combat routing, run timers, and scene music.
extends Node

const RunDataScript := preload("res://core/run_data.gd")
const DungeonFloorGeneratorScript := preload("res://core/dungeon/dungeon_floor_generator.gd")
const DungeonEncounterResolverScript := preload("res://core/dungeon/encounters/dungeon_encounter_resolver.gd")
const PlayerRunStateServiceScript := preload("res://core/party/player_run_state_service.gd")
const RewardServiceScript := preload("res://core/rewards/reward_service.gd")
const SceneRouteServiceScript := preload("res://core/scene_route_service.gd")
const DEFAULT_DUNGEON_GENERATION_CONFIG := preload("res://core/dungeon/default_dungeon_floor_generation_config.tres")
const DEFAULT_DUNGEON_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_encounter_pool.tres")
const DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres")
const DEFAULT_DUNGEON_ABILITY_POOL := preload("res://core/dungeon/abilities/default_dungeon_ability_pool.tres")

signal run_time_changed(remaining_time_seconds: float, max_time_seconds: float)
signal run_currencies_changed(memories: int, gold: int)
signal run_ended(reason: String)

const DEFAULT_ENEMY_PROFILE_PATH := "res://scenes/combatants/enemies/training_ghoul/training_ghoul_profile.tres"
const CHARACTER_PROFILE_PATHS := {
	"Warrior": "res://scenes/combatants/characters/warrior/warrior_profile.tres",
}
const DIFFICULTY_PROFILE_PATHS := {
	"easy": "res://core/difficulty/easy.tres",
	"normal": "res://core/difficulty/normal.tres",
	"hard": "res://core/difficulty/hard.tres",
}

var run_setup_data = RunDataScript.new()
var current_run_data = null
var pending_class_memory_awards: Dictionary = {}

func _ready() -> void:
	call_deferred("_play_music_for_current_scene")

func start_new_run(character: String, difficulty: String, dungeon_seed: String = "", dungeon_floor_layer: int = 1) -> Variant:
	current_run_data = RunDataScript.new()
	current_run_data.start_run(
		character,
		difficulty,
		RunDataScript.DEFAULT_RUN_TIME_SECONDS,
		DEFAULT_ENEMY_PROFILE_PATH,
		_resolve_dungeon_seed(dungeon_seed),
		max(dungeon_floor_layer, 1)
	)
	current_run_data.initialize_player_state(get_selected_character_profile(), get_selected_character_profile_path())
	_apply_run_seed(current_run_data.dungeon_seed)
	current_run_data.dungeon_node_descriptors = DungeonFloorGeneratorScript.generate_floor_from_global_rng(
		current_run_data.dungeon_floor_layer,
		current_run_data.selected_difficulty,
		DEFAULT_DUNGEON_GENERATION_CONFIG,
		DEFAULT_DUNGEON_ENCOUNTER_POOL,
		DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL
	)
	current_run_data.initialize_dungeon_map_state(RunDataScript.START_DUNGEON_NODE_ID)
	run_setup_data.configure_selection(current_run_data.selected_character, current_run_data.selected_difficulty)
	run_setup_data.dungeon_seed = current_run_data.dungeon_seed
	run_setup_data.dungeon_floor_layer = current_run_data.dungeon_floor_layer
	emit_run_state()
	play_run_music(true)
	return current_run_data

func clear_run() -> void:
	current_run_data = null

func start_combat(
	node_id: int,
	node_type: String,
	enemy_profile_path: String,
	is_boss: bool,
	charge_travel_time: bool = true,
	combat_encounter_id: StringName = &"",
	combat_encounter_profile_path: String = ""
) -> void:
	if current_run_data == null:
		start_new_run(
			run_setup_data.selected_character,
			run_setup_data.selected_difficulty,
			run_setup_data.dungeon_seed,
			run_setup_data.dungeon_floor_layer
		)

	current_run_data.set_encounter(
		node_id,
		node_type,
		enemy_profile_path,
		is_boss,
		DEFAULT_ENEMY_PROFILE_PATH,
		combat_encounter_id,
		combat_encounter_profile_path
	)

	if charge_travel_time and not advance_run_time(RunDataScript.NODE_TRAVEL_TIME):
		return

	go_to_scene("combat/BattleScene")

func complete_combat(result: Variant) -> void:
	if _is_run_ended():
		return

	if current_run_data != null:
		current_run_data.store_combat_result(result)
	go_to_scene("dungeon")

func consume_last_combat_result() -> Variant:
	if current_run_data == null:
		return null

	return current_run_data.consume_pending_combat_result()

func has_pending_combat_result() -> bool:
	return current_run_data != null and current_run_data.has_pending_combat_result()

func advance_run_time(seconds: float) -> bool:
	if current_run_data == null:
		return true
	if _is_run_ended():
		return false

	current_run_data.advance_time(seconds)
	emit_run_state()

	if current_run_data.remaining_run_time_seconds <= 0.0:
		end_current_run(RunDataScript.END_REASON_TIMEOUT)
		return false

	return true

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

func apply_dungeon_encounter_result(encounter_id: StringName, result: Dictionary) -> Dictionary:
	var outcome := {
		"handled": false,
		"damage_taken": 0,
		"stat_modifiers_added": 0,
	}
	if current_run_data == null or _is_run_ended():
		return outcome

	var mode := str(result.get("mode", "complete"))
	if mode != "complete":
		push_warning("Unsupported dungeon encounter result mode: %s" % mode)
		return outcome

	var encounter_data: Resource = get_dungeon_encounter(encounter_id)
	var choice_index := int(result.get("choice_index", -1))
	var choice_data: Dictionary = DungeonEncounterResolverScript.choice_for_index(encounter_data, choice_index)
	var effect_outcome: Dictionary = current_run_data.apply_encounter_choice(choice_data)
	outcome["handled"] = true
	outcome["damage_taken"] = int(effect_outcome.get("damage_taken", 0))
	outcome["stat_modifiers_added"] = int(effect_outcome.get("stat_modifiers_added", 0))
	emit_run_state()

	if current_run_data.is_player_defeated():
		end_current_run(RunDataScript.END_REASON_DEFEAT)

	return outcome

func apply_run_player_state_to_combatant(combatant: Variant) -> void:
	PlayerRunStateServiceScript.apply_run_state_to_combatant(current_run_data, combatant)

func get_run_player_hp_snapshot() -> Dictionary:
	return PlayerRunStateServiceScript.hp_snapshot(current_run_data)

func get_effective_player_stats() -> Dictionary:
	return PlayerRunStateServiceScript.effective_player_stats(current_run_data, get_selected_character_profile())

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

	return current_run_data.export_memories_to(pending_class_memory_awards)

func calculate_rewards_for_profile(profile: CombatantProfile, is_boss: bool) -> Dictionary:
	return RewardServiceScript.calculate_combat_rewards(profile, get_selected_difficulty_profile(), is_boss)

func get_selected_difficulty_profile() -> Resource:
	var profile_path := get_selected_difficulty_profile_path()
	if profile_path.is_empty():
		return null

	return load(profile_path)

func get_selected_character_profile() -> CombatantProfile:
	var profile_path := get_selected_character_profile_path()
	if profile_path.is_empty():
		return null

	return load(profile_path) as CombatantProfile

func get_selected_character_profile_path() -> String:
	return str(CHARACTER_PROFILE_PATHS.get(get_selected_character_id(), CHARACTER_PROFILE_PATHS[RunDataScript.DEFAULT_CHARACTER]))

func get_selected_character_id() -> String:
	if current_run_data != null:
		return current_run_data.selected_character

	return run_setup_data.selected_character

func get_selected_difficulty_id() -> String:
	if current_run_data != null:
		return current_run_data.selected_difficulty

	return run_setup_data.selected_difficulty

func get_selected_difficulty_profile_path() -> String:
	return str(DIFFICULTY_PROFILE_PATHS.get(get_selected_difficulty_id(), DIFFICULTY_PROFILE_PATHS[RunDataScript.DEFAULT_DIFFICULTY]))

func get_selected_difficulty_display_name() -> String:
	var profile := get_selected_difficulty_profile()
	if profile == null:
		return get_selected_difficulty_id().capitalize()

	return profile.display_name

func get_current_encounter() -> Dictionary:
	if current_run_data == null:
		return {
			"node_id": -1,
			"node_type": "",
			"enemy_profile_path": DEFAULT_ENEMY_PROFILE_PATH,
			"combat_encounter_id": &"",
			"combat_encounter_profile_path": "",
			"is_boss": false,
		}

	return current_run_data.get_current_encounter(DEFAULT_ENEMY_PROFILE_PATH)

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
	var sound_manager := _sound_manager()
	if sound_manager == null:
		return

	sound_manager.call("play_music", SceneRouteServiceScript.RUN_MUSIC_ID, -1.0, restart)
	sound_manager.call("set_music_state", &"", 0.0)

func scene_path_for(scene_ref: String) -> String:
	return SceneRouteServiceScript.scene_path_for(scene_ref)

func _play_music_for_current_scene() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	_play_music_for_scene_path(current_scene.scene_file_path)

func _play_music_for_scene_path(scene_path: String) -> void:
	var sound_manager := _sound_manager()
	if sound_manager == null:
		return

	var music_id := SceneRouteServiceScript.music_id_for_scene_path(scene_path)
	if String(music_id).is_empty():
		return

	sound_manager.call("play_music", music_id)
	if music_id == &"music.combat":
		sound_manager.call("set_music_state", &"combat_base", 0.0)
	else:
		sound_manager.call("set_music_state", &"", 0.0)

func _sound_manager() -> Node:
	if not is_inside_tree():
		return null

	return get_node_or_null("/root/SoundManager")

func _resolve_dungeon_seed(requested_seed: String) -> String:
	var requested_seed_text := requested_seed.strip_edges()
	if not requested_seed_text.is_empty():
		return requested_seed_text

	return "run_%s_%s" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]

func _apply_run_seed(run_seed: String) -> void:
	seed(run_seed.hash())

func _is_run_ended() -> bool:
	return current_run_data != null and current_run_data.has_ended()
