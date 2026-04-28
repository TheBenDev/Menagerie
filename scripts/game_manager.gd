extends Node

const RunDataScript := preload("res://scripts/run_data.gd")

signal run_time_changed(remaining_time_seconds: float, max_time_seconds: float)
signal run_currencies_changed(memories: int, gold: int)
signal run_ended(reason: String)

const RUN_TIME_SECONDS := 500.0
const NODE_TRAVEL_TIME_SECONDS := 30.0
const END_REASON_IN_PROGRESS := "in_progress"
const END_REASON_VICTORY := "victory"
const END_REASON_DEFEAT := "defeat"
const END_REASON_TIMEOUT := "timeout"

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const WAITING_ROOM_SCENE_PATH := "res://scenes/waiting_room.tscn"
const DUNGEON_SCENE_PATH := "res://scenes/dungeon.tscn"
const COMBAT_SCENE_PATH := "res://scenes/Battle/BattleScene.tscn"
const RUN_SUMMARY_SCENE_PATH := "res://scenes/run_summary.tscn"

const MAIN_MENU_MUSIC_ID := &"main_menu"
const WAITING_ROOM_MUSIC_ID := &"waiting_room"
const DUNGEON_MUSIC_ID := &"dungeon"
const COMBAT_MUSIC_ID := &"combat"
const COMBAT_BASE_MUSIC_STATE_ID := &"combat_base"
const RUN_ENDS_LOOP_SFX_ID := &"run_ends_loop"
const BOSS_START_FIGHT_SFX_ID := &"boss_start_fight"

const DEFAULT_ENEMY_PROFILE_PATH := "res://data/enemies/Training_Ghoul/training_ghoul_profile.tres"
const CHARACTER_PROFILE_PATHS := {
	"Warrior": "res://data/characters/Warrior/warrior_profile.tres",
}
const DIFFICULTY_PROFILE_PATHS := {
	"easy": "res://data/difficulty/easy.tres",
	"normal": "res://data/difficulty/normal.tres",
	"hard": "res://data/difficulty/hard.tres",
}

var selected_character: String = "Warrior"
var selected_difficulty: String = "normal"
var current_run_data = null
var last_combat_result = null
var current_node_id: int = -1
var current_node_type: String = ""
var current_enemy_profile_path: String = DEFAULT_ENEMY_PROFILE_PATH
var current_is_boss: bool = false
var pending_class_memory_awards: Dictionary = {}

func _ready() -> void:
	call_deferred("_play_music_for_current_scene")

func start_new_run(character: String, difficulty: String) -> Variant:
	selected_character = character
	selected_difficulty = difficulty
	last_combat_result = null
	current_node_id = -1
	current_node_type = ""
	current_enemy_profile_path = DEFAULT_ENEMY_PROFILE_PATH
	current_is_boss = false

	current_run_data = RunDataScript.new()
	current_run_data.selected_character = selected_character
	current_run_data.selected_difficulty = selected_difficulty
	current_run_data.current_node_index = 0
	current_run_data.reset_run_timer(RUN_TIME_SECONDS)
	emit_run_state()
	return current_run_data

func clear_run() -> void:
	current_run_data = null
	last_combat_result = null
	current_node_id = -1
	current_node_type = ""
	current_enemy_profile_path = DEFAULT_ENEMY_PROFILE_PATH
	current_is_boss = false

func start_combat(node_id: int, node_type: String, enemy_profile_path: String, is_boss: bool) -> void:
	current_node_id = node_id
	current_node_type = node_type
	current_enemy_profile_path = enemy_profile_path if not enemy_profile_path.is_empty() else DEFAULT_ENEMY_PROFILE_PATH
	current_is_boss = is_boss
	last_combat_result = null

	if not advance_run_time(NODE_TRAVEL_TIME_SECONDS):
		return

	go_to_scene(COMBAT_SCENE_PATH)

func complete_combat(result: Variant) -> void:
	if _is_run_ended():
		return

	last_combat_result = result
	go_to_scene(DUNGEON_SCENE_PATH)

func consume_last_combat_result() -> Variant:
	var result = last_combat_result
	last_combat_result = null
	return result

func advance_run_time(seconds: float) -> bool:
	if current_run_data == null:
		return true
	if _is_run_ended():
		return false

	current_run_data.advance_time(seconds)
	emit_run_state()

	if current_run_data.remaining_run_time_seconds <= 0.0:
		end_current_run(END_REASON_TIMEOUT)
		return false

	return true

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
	call_deferred("go_to_run_summary")

func emit_run_state() -> void:
	if current_run_data == null:
		run_time_changed.emit(0.0, RUN_TIME_SECONDS)
		run_currencies_changed.emit(0, 0)
		return

	run_time_changed.emit(current_run_data.remaining_run_time_seconds, current_run_data.max_run_time_seconds)
	run_currencies_changed.emit(current_run_data.memories, current_run_data.gold)

func export_current_run_memories() -> int:
	if current_run_data == null or current_run_data.memories_exported:
		return 0

	current_run_data.memories_exported = true
	var awarded_memories: int = max(current_run_data.memories, 0)
	if awarded_memories <= 0:
		return 0

	var current_total: int = int(pending_class_memory_awards.get(current_run_data.selected_character, 0))
	pending_class_memory_awards[current_run_data.selected_character] = current_total + awarded_memories
	return awarded_memories

func calculate_rewards_for_profile(profile: Resource, is_boss: bool) -> Dictionary:
	var rewards := {
		"memories_awarded": 0,
		"gold_awarded": 0,
	}
	if profile == null:
		return rewards

	var reward_profile := profile.get("reward_profile") as Resource
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

func get_selected_character_profile() -> Resource:
	var profile_path := str(CHARACTER_PROFILE_PATHS.get(selected_character, CHARACTER_PROFILE_PATHS["Warrior"]))
	if profile_path.is_empty():
		return null

	return load(profile_path)

func get_selected_difficulty_profile_path() -> String:
	return str(DIFFICULTY_PROFILE_PATHS.get(selected_difficulty, DIFFICULTY_PROFILE_PATHS["normal"]))

func get_selected_difficulty_display_name() -> String:
	var profile := get_selected_difficulty_profile()
	if profile == null:
		return selected_difficulty.capitalize()

	return profile.display_name

func go_to_main_menu() -> void:
	go_to_scene(MAIN_MENU_SCENE_PATH)

func go_to_waiting_room() -> void:
	go_to_scene(WAITING_ROOM_SCENE_PATH)

func go_to_dungeon() -> void:
	go_to_scene(DUNGEON_SCENE_PATH)

func go_to_run_summary() -> void:
	go_to_scene(RUN_SUMMARY_SCENE_PATH)

func go_to_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s. Error: %s" % [scene_path, error])
		return

	play_music_for_scene(scene_path)

func play_music_for_scene(scene_path: String) -> void:
	_play_music_for_scene_path(scene_path)

func play_sfx(sfx_id: StringName, options: Dictionary = {}) -> void:
	var sound_manager := _sound_manager()
	if sound_manager == null or String(sfx_id).is_empty():
		return

	sound_manager.call("play_sfx", sfx_id, options)

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
	if music_id == COMBAT_MUSIC_ID:
		sound_manager.call("set_music_state", COMBAT_BASE_MUSIC_STATE_ID, 0.0)
	else:
		sound_manager.call("set_music_state", &"", 0.0)

func _music_id_for_scene_path(scene_path: String) -> StringName:
	match scene_path:
		MAIN_MENU_SCENE_PATH:
			return MAIN_MENU_MUSIC_ID
		WAITING_ROOM_SCENE_PATH:
			return WAITING_ROOM_MUSIC_ID
		DUNGEON_SCENE_PATH, COMBAT_SCENE_PATH:
			return DUNGEON_MUSIC_ID
		RUN_SUMMARY_SCENE_PATH:
			return MAIN_MENU_MUSIC_ID

	return &""

func _has_sound_manager() -> bool:
	return _sound_manager() != null

func _sound_manager() -> Node:
	return get_node_or_null("/root/SoundManager")

func _is_run_ended() -> bool:
	return current_run_data != null and current_run_data.run_end_reason != END_REASON_IN_PROGRESS

func _variant_int(source: Variant, field_name: String, default_value: int) -> int:
	if source is Dictionary:
		return int(source.get(field_name, default_value))

	if source != null:
		var value: Variant = source.get(field_name)
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
