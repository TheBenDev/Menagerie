## Autoload director that decides route/run/combat music context and delegates playback to SoundManager.
extends Node

const SceneRouteServiceScript := preload("res://core/scene_route_service.gd")

const MUSIC_MAIN_MENU := &"music.main_menu"
const MUSIC_WAITING_ROOM := &"music.waiting_room"
const MUSIC_DUNGEON := &"music.dungeon"
const MUSIC_COMBAT := &"music.combat"
const MUSIC_STATE_COMBAT_BASE := &"combat_base"
const MUSIC_STATE_COMBAT_TENSE := &"combat_tense"
const MUSIC_STATE_COMBAT_CRITICAL := &"combat_critical"

const ROUTE_MUSIC_IDS := {
	&"main_menu": MUSIC_MAIN_MENU,
	&"waiting_room": MUSIC_WAITING_ROOM,
	&"dungeon": MUSIC_DUNGEON,
	&"combat": MUSIC_DUNGEON,
	&"combat/BattleScene": MUSIC_DUNGEON,
	&"run_summary": MUSIC_MAIN_MENU,
}

const SCENE_PATH_MUSIC_IDS := {
	"res://scenes/ui/main_menu/MainMenu.tscn": MUSIC_MAIN_MENU,
	"res://scenes/ui/waiting_room/WaitingRoom.tscn": MUSIC_WAITING_ROOM,
	"res://scenes/dungeon/DungeonMap.tscn": MUSIC_DUNGEON,
	"res://scenes/combat/BattleScene.tscn": MUSIC_DUNGEON,
	"res://scenes/ui/run_summary/RunSummary.tscn": MUSIC_MAIN_MENU,
}

func on_route_changed(route_id: StringName) -> void:
	var music_id := _music_id_for_route_or_scene(route_id)
	_play_music(music_id)
	if _is_combat_route(route_id):
		_set_music_state(MUSIC_STATE_COMBAT_BASE, 0.0)
	else:
		_set_music_state(&"", 0.0)

func on_run_started() -> void:
	on_dungeon_entered({"restart": true})

func on_dungeon_entered(context: Dictionary = {}) -> void:
	_play_music(MUSIC_DUNGEON, -1.0, bool(context.get("restart", false)))
	_set_music_state(&"", 0.0)

func on_combat_started(context: Dictionary = {}) -> void:
	_play_music(MUSIC_DUNGEON)
	var is_boss := bool(context.get("is_boss", false))
	_set_music_state(MUSIC_STATE_COMBAT_TENSE if is_boss else MUSIC_STATE_COMBAT_BASE, 0.25 if is_boss else 0.0)

func on_combat_ended(_result: Variant = null) -> void:
	on_dungeon_entered({"restart": false})

func set_combat_music_pressure(intensity: float) -> void:
	var clamped_intensity: float = clamp(intensity, 0.0, 1.0)
	if clamped_intensity >= 0.7:
		_set_music_state(MUSIC_STATE_COMBAT_CRITICAL, clamped_intensity)
	elif clamped_intensity >= 0.35:
		_set_music_state(MUSIC_STATE_COMBAT_TENSE, clamped_intensity)
	else:
		_set_music_state(MUSIC_STATE_COMBAT_BASE, clamped_intensity)

func stop_music() -> void:
	var sound_manager := _sound_manager()
	if sound_manager != null:
		sound_manager.call("stop_music")

func _play_music(music_id: StringName, fade_seconds: float = -1.0, restart: bool = false) -> void:
	if String(music_id).is_empty():
		return

	var sound_manager := _sound_manager()
	if sound_manager != null:
		sound_manager.call("play_music", music_id, fade_seconds, restart)

func _set_music_state(state_id: StringName, intensity: float) -> void:
	var sound_manager := _sound_manager()
	if sound_manager != null:
		sound_manager.call("set_music_state", state_id, intensity)

func _sound_manager() -> Node:
	return get_node_or_null("/root/SoundManager")

func _music_id_for_route_or_scene(route_id: StringName) -> StringName:
	var music_id := StringName(ROUTE_MUSIC_IDS.get(route_id, &""))
	if not String(music_id).is_empty():
		return music_id

	var scene_path := SceneRouteServiceScript.scene_path_for(String(route_id))
	return StringName(SCENE_PATH_MUSIC_IDS.get(scene_path, &""))

func _is_combat_route(route_id: StringName) -> bool:
	var route_text := String(route_id)
	if route_text == "combat" or route_text == "combat/BattleScene":
		return true

	return SceneRouteServiceScript.scene_path_for(route_text) == "res://scenes/combat/BattleScene.tscn"
