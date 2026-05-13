## Autoload that owns run setup, scene transitions, rewards, run timers, and explicit music routing.
extends Node

const RunDataScript := preload("res://core/run_data.gd")
const DungeonFloorGeneratorScript := preload("res://core/dungeon/dungeon_floor_generator.gd")
const DungeonEncounterResolverScript := preload("res://core/dungeon/encounters/dungeon_encounter_resolver.gd")
const DEFAULT_DUNGEON_GENERATION_CONFIG := preload("res://core/dungeon/default_dungeon_floor_generation_config.tres")
const DEFAULT_DUNGEON_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_encounter_pool.tres")

signal run_time_changed(remaining_time_seconds: float, max_time_seconds: float)
signal run_currencies_changed(memories: int, gold: int)
signal run_ended(reason: String)

const SCENE_ROOT_PATH := "res://scenes"
const SCENE_EXTENSION := ".tscn"
const SCENE_ROUTE_PATHS := {
	"main_menu": "ui/main_menu/MainMenu",
	"waiting_room": "ui/waiting_room/WaitingRoom",
	"run_summary": "ui/run_summary/RunSummary",
	"dungeon": "dungeon/DungeonMap",
}
const SCENE_MUSIC_IDS := {
	"res://scenes/ui/main_menu/MainMenu.tscn": &"music.main_menu",
	"res://scenes/ui/waiting_room/WaitingRoom.tscn": &"music.waiting_room",
	"res://scenes/dungeon/DungeonMap.tscn": &"music.dungeon",
	"res://scenes/combat/BattleScene.tscn": &"music.combat",
	"res://scenes/ui/run_summary/RunSummary.tscn": &"music.main_menu",
}
const RUN_MUSIC_ID := &"music.dungeon"

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
	current_run_data.initialize_player_state(get_selected_character_profile())
	_apply_run_seed(current_run_data.dungeon_seed)
	current_run_data.dungeon_node_descriptors = DungeonFloorGeneratorScript.generate_floor_from_global_rng(
		current_run_data.dungeon_floor_layer,
		current_run_data.selected_difficulty,
		DEFAULT_DUNGEON_GENERATION_CONFIG,
		DEFAULT_DUNGEON_ENCOUNTER_POOL
	)
	run_setup_data.configure_selection(current_run_data.selected_character, current_run_data.selected_difficulty)
	run_setup_data.dungeon_seed = current_run_data.dungeon_seed
	run_setup_data.dungeon_floor_layer = current_run_data.dungeon_floor_layer
	emit_run_state()
	play_run_music(true)
	return current_run_data

func clear_run() -> void:
	current_run_data = null

func start_combat(node_id: int, node_type: String, enemy_profile_path: String, is_boss: bool) -> void:
	if current_run_data == null:
		start_new_run(
			run_setup_data.selected_character,
			run_setup_data.selected_difficulty,
			run_setup_data.dungeon_seed,
			run_setup_data.dungeon_floor_layer
		)

	current_run_data.set_encounter(node_id, node_type, enemy_profile_path, is_boss, DEFAULT_ENEMY_PROFILE_PATH)

	if not advance_run_time(RunDataScript.NODE_TRAVEL_TIME_SECONDS):
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
	if current_run_data == null or combatant == null:
		return

	current_run_data.apply_player_stats_to_combatant(combatant)

func get_run_player_hp_snapshot() -> Dictionary:
	if current_run_data == null:
		return {
			"current": 0,
			"max": 0,
		}

	return {
		"current": current_run_data.player_current_hp,
		"max": current_run_data.player_max_hp,
	}

func get_effective_player_stats() -> Dictionary:
	if current_run_data == null:
		var profile := get_selected_character_profile()
		return {
			RunDataScript.STAT_STRENGTH: _profile_int(profile, "strength", 0),
			RunDataScript.STAT_DEXTERITY: _profile_int(profile, "dexterity", 0),
			RunDataScript.STAT_INTELLIGENCE: _profile_int(profile, "intelligence", 0),
			RunDataScript.STAT_VITALITY: _profile_int(profile, "vitality", 0),
		}

	return current_run_data.get_effective_stats()

func grant_run_rewards(reward_result: Variant) -> void:
	if current_run_data == null or reward_result == null:
		return

	var memories_awarded: int = _variant_int(reward_result, "memories_awarded", 0)
	var gold_awarded: int = _variant_int(reward_result, "gold_awarded", 0)
	current_run_data.grant_rewards(memories_awarded, gold_awarded)
	emit_run_state()

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
	var rewards := {
		"memories_awarded": 0,
		"gold_awarded": 0,
	}
	if profile == null:
		return rewards

	var reward_profile := profile.reward_profile
	if reward_profile == null:
		return rewards

	var difficulty_multiplier := _difficulty_float(get_selected_difficulty_profile(), "reward_multiplier", 1.0)
	var encounter_multiplier := 1.0
	if is_boss:
		encounter_multiplier = _reward_float(reward_profile, "boss_multiplier", 4.0)

	var reward_multiplier := difficulty_multiplier * encounter_multiplier
	rewards["memories_awarded"] = max(int(round(_reward_float(reward_profile, "base_memories", 0.0) * reward_multiplier)), 0)
	rewards["gold_awarded"] = max(int(round(_reward_float(reward_profile, "base_gold", 0.0) * reward_multiplier)), 0)
	return rewards

func get_selected_difficulty_profile() -> Resource:
	var profile_path := get_selected_difficulty_profile_path()
	if profile_path.is_empty():
		return null

	return load(profile_path)

func get_selected_character_profile() -> CombatantProfile:
	var profile_path := str(CHARACTER_PROFILE_PATHS.get(get_selected_character_id(), CHARACTER_PROFILE_PATHS[RunDataScript.DEFAULT_CHARACTER]))
	if profile_path.is_empty():
		return null

	return load(profile_path) as CombatantProfile

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

	sound_manager.call("play_music", RUN_MUSIC_ID, -1.0, restart)
	sound_manager.call("set_music_state", &"", 0.0)

func scene_path_for(scene_ref: String) -> String:
	var normalized_ref := scene_ref.strip_edges().replace("\\", "/")
	if normalized_ref.is_empty():
		return ""

	if normalized_ref.begins_with("res://"):
		return _with_scene_extension(normalized_ref)

	normalized_ref = normalized_ref.trim_prefix("/")
	if normalized_ref.begins_with("scenes/"):
		normalized_ref = normalized_ref.substr("scenes/".length())
	normalized_ref = _scene_route_path_for(normalized_ref)

	return _with_scene_extension(SCENE_ROOT_PATH.path_join(normalized_ref))

func _play_music_for_current_scene() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	_play_music_for_scene_path(current_scene.scene_file_path)

func _play_music_for_scene_path(scene_path: String) -> void:
	var sound_manager := _sound_manager()
	if sound_manager == null:
		return

	var music_id := _music_id_for_scene_path(scene_path)
	if String(music_id).is_empty():
		return

	sound_manager.call("play_music", music_id)
	if music_id == &"music.combat":
		sound_manager.call("set_music_state", &"combat_base", 0.0)
	else:
		sound_manager.call("set_music_state", &"", 0.0)

func _music_id_for_scene_path(scene_path: String) -> StringName:
	var normalized_scene_path := scene_path_for(scene_path)
	return StringName(SCENE_MUSIC_IDS.get(normalized_scene_path, &""))

func _scene_route_path_for(scene_ref: String) -> String:
	var route_key := scene_ref
	if route_key.ends_with(SCENE_EXTENSION):
		route_key = route_key.substr(0, route_key.length() - SCENE_EXTENSION.length())

	return str(SCENE_ROUTE_PATHS.get(route_key, scene_ref))

func _with_scene_extension(scene_path: String) -> String:
	if scene_path.ends_with(SCENE_EXTENSION):
		return scene_path
	if scene_path.get_extension().is_empty():
		return scene_path + SCENE_EXTENSION

	return scene_path

func _sound_manager() -> Node:
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

func _variant_int(source: Variant, field_name: String, default_value: int) -> int:
	if source is Dictionary:
		return int(source.get(field_name, default_value))

	if source != null:
		var value: Variant = source.get(field_name)
		if value is int or value is float:
			return int(value)

	return default_value

func _profile_int(profile: Resource, field_name: String, default_value: int) -> int:
	if profile == null:
		return default_value

	var value: Variant = profile.get(field_name)
	if value is int or value is float:
		return int(value)

	return default_value

func _difficulty_float(active_difficulty: Resource, field_name: String, default_value: float) -> float:
	if active_difficulty == null:
		return default_value

	var value: Variant = active_difficulty.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value

func _reward_float(reward_profile: Resource, field_name: String, default_value: float) -> float:
	if reward_profile == null:
		return default_value

	var value: Variant = reward_profile.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value
