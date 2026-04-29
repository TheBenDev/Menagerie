## Autoload audio service for registering cues, playing SFX/UI sounds, and crossfading music tracks.
extends Node

const AudioCueDataScript := preload("res://scripts/data/audio/audio_cue_data.gd")
const AudioRegistryScript := preload("res://scripts/audio/audio_registry.gd")

const DEFAULT_LIBRARY_PATH := "res://data/audio/common_audio_library.tres"
const DEFAULT_SOUND_ROOT_PATH := "res://sounds"
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const SFX_POOL_SIZE := 24
const UI_POOL_SIZE := 8
const SILENT_VOLUME_DB := -80.0
const DEFAULT_SWITCH_FADE_SECONDS := 2.0
const DEFAULT_STOP_FADE_SECONDS := 2.0
const BUTTON_CLICK_CUE_ID := &"ui.button.click"
const LEGACY_ID_ALIASES := {
	&"button_click": &"ui.button.click",
	&"run_ends_loop": &"sfx.global.death.run_ends_loop",
	&"boss_start_fight": &"sfx.boss.boss_start_fight",
	&"diddy_jocky": &"sfx.enemy.jockey.diddy_jocky",
	&"main_menu": &"music.main_menu",
	&"waiting_room": &"music.waiting_room",
	&"dungeon": &"music.dungeon",
	&"combat": &"music.combat",
}

var library: Resource = null

var _audio_registry = AudioRegistryScript.new()
var _cues: Dictionary = {}
var _music_tracks: Dictionary = {}
var _missing_warnings: Dictionary = {}
var _cue_last_played_seconds: Dictionary = {}
var _active_instances_by_cue: Dictionary = {}
var _player_metadata: Dictionary = {}
var _connected_button_ids: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _music_player_loop_flags: Dictionary = {}
var _active_music_player_index: int = 0
var _music_fade_tween: Tween = null

var _current_music_track: Resource = null
var _current_music_id: StringName = &""
var _current_music_state_id: StringName = &""
var _pending_music_state_id: StringName = &""
var _current_music_intensity: float = 0.0
var _music_state_started_msec: int = 0
var _music_state_hold_seconds: float = 0.0
var _playlist_next_crossfade_seconds: float = 0.0
var _playlist_crossfade_started: bool = false

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_runtime_buses()
	_create_music_players()
	_create_player_pool(_sfx_players, SFX_POOL_SIZE, BUS_SFX, "SFXPlayer")
	_create_player_pool(_ui_players, UI_POOL_SIZE, BUS_UI, "UIPlayer")
	_scan_audio_registry()
	load_library(DEFAULT_LIBRARY_PATH)
	if not get_tree().node_added.is_connected(_on_scene_node_added):
		get_tree().node_added.connect(_on_scene_node_added)
	call_deferred("_connect_existing_buttons")
	set_process(true)

func _process(_delta: float) -> void:
	_try_apply_pending_music_state()
	_update_music_playlist()

func _exit_tree() -> void:
	if _music_fade_tween != null:
		_music_fade_tween.kill()
		_music_fade_tween = null

	for player in _music_players:
		_clear_audio_player(player)
	for player in _sfx_players:
		_clear_audio_player(player)
	for player in _ui_players:
		_clear_audio_player(player)

	library = null
	_audio_registry.streams_by_id.clear()
	_audio_registry.paths_by_id.clear()
	_audio_registry.ids_by_path.clear()
	_cues.clear()
	_music_tracks.clear()
	_current_music_track = null
	_music_player_loop_flags.clear()
	_connected_button_ids.clear()
	_player_metadata.clear()
	_active_instances_by_cue.clear()

func load_library(library_path: String) -> void:
	var loaded_library: Resource = load(library_path) as Resource
	if loaded_library == null:
		library = null
		_reset_audio_catalog(null)
		_warn_once(StringName("library:%s" % library_path), "Audio library could not be loaded: %s" % library_path)
		return

	set_library(loaded_library)

func set_library(new_library: Resource) -> void:
	library = new_library
	_reset_audio_catalog(library)

func _reset_audio_catalog(active_library: Resource) -> void:
	_cues.clear()
	_music_tracks.clear()
	_register_scanned_cues()

	if active_library == null:
		return

	var raw_cues: Variant = active_library.get("cues")
	if raw_cues is Array:
		for raw_cue in raw_cues:
			var cue: Resource = raw_cue as Resource
			var cue_id := _canonical_audio_id(_resource_string_name(cue, "id"))
			if cue != null and not String(cue_id).is_empty():
				cue.set("id", cue_id)
				if _cues.has(cue_id) and not _cue_has_authored_streams(cue):
					_merge_cue_override(_cues[cue_id] as Resource, cue)
				else:
					_cues[cue_id] = cue

	var raw_music_tracks: Variant = active_library.get("music_tracks")
	if raw_music_tracks is Array:
		for raw_track in raw_music_tracks:
			var track: Resource = raw_track as Resource
			var track_id := _canonical_audio_id(_resource_string_name(track, "id"))
			if track != null and not String(track_id).is_empty():
				track.set("id", track_id)
				_music_tracks[track_id] = track

func _scan_audio_registry() -> void:
	_audio_registry.scan(DEFAULT_SOUND_ROOT_PATH)
	for failed_path in _audio_registry.failed_paths:
		_warn_once(
			StringName("registry_failed:%s" % failed_path),
			"Audio registry could not load stream: %s" % failed_path
		)
	for raw_id in _audio_registry.duplicate_paths.keys():
		var stream_id := StringName(raw_id)
		var paths: PackedStringArray = []
		for raw_path in _audio_registry.duplicate_paths[stream_id]:
			paths.append(str(raw_path))
		_warn_once(
			StringName("registry_duplicate:%s" % stream_id),
			"Audio registry duplicate stream id %s. Keeping first path from: %s" % [stream_id, ", ".join(paths)]
		)

func _register_scanned_cues() -> void:
	for stream_id in _audio_registry.get_stream_ids():
		var cue_bus := _auto_cue_bus(stream_id)
		if String(cue_bus).is_empty():
			continue

		var cue_id := _auto_cue_id_for_stream_id(stream_id)
		var cue := _cues.get(cue_id, null) as Resource
		if cue == null:
			cue = AudioCueDataScript.new()
			cue.set("id", cue_id)
			cue.set("bus", cue_bus)
			_cues[cue_id] = cue

		_append_cue_stream_id(cue, stream_id)

func _auto_cue_bus(stream_id: StringName) -> StringName:
	var stream_id_text := String(stream_id)
	if stream_id_text.begins_with("sfx."):
		return BUS_SFX
	if stream_id_text.begins_with("ui."):
		return BUS_UI

	return &""

func _auto_cue_id_for_stream_id(stream_id: StringName) -> StringName:
	var parts := String(stream_id).split(".", false)
	if parts.is_empty():
		return stream_id

	var final_part := parts[parts.size() - 1]
	var variant_base := _numbered_variant_base(final_part)
	if not variant_base.is_empty():
		parts[parts.size() - 1] = variant_base

	var cue_parts: PackedStringArray = []
	for part in parts:
		cue_parts.append(part)

	return StringName(".".join(cue_parts))

func _numbered_variant_base(value: String) -> String:
	var separator_index := value.rfind("_")
	if separator_index <= 0 or separator_index >= value.length() - 1:
		return ""

	var suffix := value.substr(separator_index + 1)
	for index in range(suffix.length()):
		var code := suffix.unicode_at(index)
		if code < 48 or code > 57:
			return ""

	return value.substr(0, separator_index)

func _append_cue_stream_id(cue: Resource, stream_id: StringName) -> void:
	var stream_ids := _raw_stream_ids(cue, "stream_ids")
	if stream_ids.has(stream_id):
		return

	stream_ids.append(stream_id)
	cue.set("stream_ids", stream_ids)

func _merge_cue_override(target_cue: Resource, override_cue: Resource) -> void:
	if target_cue == null or override_cue == null:
		return

	for field_name in [
		"bus",
		"volume_db",
		"pitch_min",
		"pitch_max",
		"cooldown_seconds",
		"max_instances",
		"priority",
	]:
		target_cue.set(field_name, override_cue.get(field_name))

func _cue_has_authored_streams(cue: Resource) -> bool:
	if cue == null:
		return false

	return not _raw_stream_ids(cue, "stream_ids").is_empty() or not _raw_audio_streams(cue, "streams").is_empty()

func play_sfx(id: StringName, options: Dictionary = {}) -> void:
	_play_cue(id, _sfx_players, BUS_SFX, options)

func play_ui(id: StringName, options: Dictionary = {}) -> void:
	_play_cue(id, _ui_players, BUS_UI, options)

func _connect_existing_buttons() -> void:
	_connect_buttons_in_tree(get_tree().root)

func _connect_buttons_in_tree(node: Node) -> void:
	_try_connect_button(node)
	for child in node.get_children():
		_connect_buttons_in_tree(child)

func _on_scene_node_added(node: Node) -> void:
	_try_connect_button(node)

func _try_connect_button(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return

	var instance_id := button.get_instance_id()
	if _connected_button_ids.has(instance_id):
		return

	button.pressed.connect(_on_button_pressed.bind(button))
	_connected_button_ids[instance_id] = true

func _on_button_pressed(_button: BaseButton) -> void:
	play_ui(BUTTON_CLICK_CUE_ID)

func play_music(id: StringName, fade_seconds: float = -1.0, restart: bool = false) -> void:
	var track_id := _canonical_audio_id(id)
	if String(track_id).is_empty():
		return

	var track: Resource = _music_tracks.get(track_id, null) as Resource
	if track == null:
		_warn_once(StringName("music:%s" % track_id), "Music track is not registered: %s" % track_id)
		return

	var active_player := _active_music_player()
	if _current_music_id == track_id and active_player != null and active_player.playing and not restart:
		return

	if _should_suppress_playback():
		_current_music_id = track_id
		return

	var resolved_fade_seconds := fade_seconds
	if resolved_fade_seconds < 0.0:
		resolved_fade_seconds = _default_music_switch_fade_seconds(track)

	var stream := _stream_for_track(track)
	if not restart and _can_continue_current_music(active_player, stream):
		_continue_current_music(track, active_player, resolved_fade_seconds)
		return

	_start_music_stream(track, stream, resolved_fade_seconds)

func stop_music(fade_seconds: float = DEFAULT_STOP_FADE_SECONDS) -> void:
	var active_player := _active_music_player()
	_current_music_id = &""
	_current_music_track = null
	_pending_music_state_id = &""
	_playlist_crossfade_started = false

	if active_player == null or not active_player.playing:
		return

	if _music_fade_tween != null:
		_music_fade_tween.kill()
		_music_fade_tween = null

	if fade_seconds <= 0.0:
		_stop_music_player(active_player)
		return

	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(active_player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	_music_fade_tween.tween_callback(_stop_music_player.bind(active_player))

func set_music_state(state_id: StringName, intensity: float = 0.0) -> void:
	if String(state_id).is_empty():
		_pending_music_state_id = &""
		_current_music_state_id = &""
		_current_music_intensity = 0.0
		_music_state_hold_seconds = 0.0
		return

	_pending_music_state_id = StringName(state_id)
	_current_music_intensity = clamp(intensity, 0.0, 1.0)
	_try_apply_pending_music_state()

func set_bus_volume(bus_name: StringName, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		_warn_once(StringName("bus:%s" % bus_name), "Audio bus does not exist: %s" % bus_name)
		return

	var clamped_value: float = clamp(linear_value, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped_value <= 0.0)
	if clamped_value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped_value))

func get_current_music_id() -> StringName:
	return _current_music_id

func get_current_music_state_id() -> StringName:
	return _current_music_state_id

func is_music_playing() -> bool:
	for player in _music_players:
		if player != null and player.playing:
			return true

	return false

func has_audio_stream(id: StringName) -> bool:
	return _audio_registry.has_stream(_canonical_audio_id(id))

func get_registered_audio_stream_ids() -> Array[StringName]:
	return _audio_registry.get_stream_ids()

func get_music_debug_state() -> Dictionary:
	var player_states: Array[Dictionary] = []
	for player in _music_players:
		if player == null:
			continue

		player_states.append({
			"name": player.name,
			"playing": player.playing,
			"has_stream": player.stream != null,
			"stream": player.stream.resource_path if player.stream != null else "",
			"bus": player.bus,
			"volume_db": player.volume_db,
			"playback_position": player.get_playback_position() if player.playing else 0.0,
			"playback": str(player.get_stream_playback()) if player.playing else "<inactive>",
		})

	var music_bus_index := AudioServer.get_bus_index(BUS_MUSIC)
	return {
		"display_server": DisplayServer.get_name(),
		"current_music_id": _current_music_id,
		"current_music_track_has_playlist": _track_playlist_streams(_current_music_track).size() > 0,
		"playlist_next_crossfade_seconds": _playlist_next_crossfade_seconds,
		"registry_stream_count": _audio_registry.get_stream_count(),
		"cue_count": _cues.size(),
		"music_track_count": _music_tracks.size(),
		"music_bus_index": music_bus_index,
		"music_bus_muted": AudioServer.is_bus_mute(music_bus_index) if music_bus_index >= 0 else true,
		"music_bus_volume_db": AudioServer.get_bus_volume_db(music_bus_index) if music_bus_index >= 0 else 0.0,
		"active_music_player_index": _active_music_player_index,
		"players": player_states,
	}

func _play_cue(id: StringName, pool: Array[AudioStreamPlayer], default_bus: StringName, options: Dictionary) -> void:
	var cue_id := _canonical_audio_id(id)
	if String(cue_id).is_empty():
		return

	var cue: Resource = _cues.get(cue_id, null) as Resource
	if cue == null:
		_warn_once(StringName("cue:%s" % cue_id), "Audio cue is not registered: %s" % cue_id)
		return
	if _cue_streams(cue).is_empty():
		_warn_once(StringName("cue_streams:%s" % cue_id), "Audio cue has no streams: %s" % cue_id)
		return
	if _should_suppress_playback():
		return

	var now_seconds := _now_seconds()
	var last_played_seconds := float(_cue_last_played_seconds.get(cue_id, -1000000.0))
	var cooldown_seconds := _resource_float(cue, "cooldown_seconds", 0.0)
	if cooldown_seconds > 0.0 and now_seconds - last_played_seconds < cooldown_seconds:
		return

	var priority := int(options.get("priority", _resource_int(cue, "priority", 0)))
	var player := _player_for_cue(cue_id, cue, pool, priority)
	if player == null:
		return

	var stream := _random_stream(cue)
	if stream == null:
		_warn_once(StringName("cue_stream_null:%s" % cue_id), "Audio cue selected a null stream: %s" % cue_id)
		return

	_release_player(player)
	_cue_last_played_seconds[cue_id] = now_seconds
	_register_player(player, cue_id, priority)

	player.stream = stream
	player.bus = _bus_from_options(options, _resource_string_name(cue, "bus", default_bus), default_bus)
	player.volume_db = _resource_float(cue, "volume_db", 0.0) + float(options.get("volume_db", 0.0))
	player.pitch_scale = _pitch_for_cue(cue) * float(options.get("pitch_scale", 1.0))
	player.play()

func _player_for_cue(
	cue_id: StringName,
	cue: Resource,
	pool: Array[AudioStreamPlayer],
	priority: int
) -> AudioStreamPlayer:
	var max_instances: int = max(_resource_int(cue, "max_instances", 8), 1)
	if _active_cue_count(cue_id) >= max_instances:
		var same_cue_player := _lowest_priority_oldest_player(pool, cue_id)
		if same_cue_player == null or _player_priority(same_cue_player) > priority:
			return null

		same_cue_player.stop()
		return same_cue_player

	var available_player := _available_player(pool)
	if available_player != null:
		return available_player

	var stealable_player := _lowest_priority_oldest_player(pool)
	if stealable_player == null or _player_priority(stealable_player) > priority:
		return null

	stealable_player.stop()
	return stealable_player

func _random_stream(cue: Resource) -> AudioStream:
	var streams: Array = _cue_streams(cue)
	var stream_index := _rng.randi_range(0, streams.size() - 1)
	return streams[stream_index] as AudioStream

func _pitch_for_cue(cue: Resource) -> float:
	var pitch_min := _resource_float(cue, "pitch_min", 1.0)
	var pitch_max := _resource_float(cue, "pitch_max", 1.0)
	var low: float = max(min(pitch_min, pitch_max), 0.01)
	var high: float = max(max(pitch_min, pitch_max), 0.01)
	if is_equal_approx(low, high):
		return low

	return _rng.randf_range(low, high)

func _active_cue_count(cue_id: StringName) -> int:
	return int(_active_instances_by_cue.get(cue_id, 0))

func _available_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in pool:
		if player != null and not player.playing:
			return player

	return null

func _lowest_priority_oldest_player(pool: Array[AudioStreamPlayer], cue_id: StringName = &"") -> AudioStreamPlayer:
	var selected_player: AudioStreamPlayer = null
	var selected_priority := 2147483647
	var selected_started_at := 9223372036854775807

	for player in pool:
		if player == null or not player.playing:
			continue
		var metadata := _metadata_for_player(player)
		if not String(cue_id).is_empty() and metadata.get("cue_id", &"") != cue_id:
			continue

		var player_priority := int(metadata.get("priority", 0))
		var started_at := int(metadata.get("started_at", 0))
		if selected_player == null or player_priority < selected_priority or (
			player_priority == selected_priority and started_at < selected_started_at
		):
			selected_player = player
			selected_priority = player_priority
			selected_started_at = started_at

	return selected_player

func _player_priority(player: AudioStreamPlayer) -> int:
	return int(_metadata_for_player(player).get("priority", 0))

func _register_player(player: AudioStreamPlayer, cue_id: StringName, priority: int) -> void:
	_player_metadata[player.get_instance_id()] = {
		"cue_id": cue_id,
		"priority": priority,
		"started_at": Time.get_ticks_msec(),
	}
	_active_instances_by_cue[cue_id] = _active_cue_count(cue_id) + 1

func _release_player(player: AudioStreamPlayer) -> void:
	var instance_id := player.get_instance_id()
	if not _player_metadata.has(instance_id):
		return

	var metadata: Dictionary = _player_metadata[instance_id]
	var cue_id := StringName(metadata.get("cue_id", &""))
	if not String(cue_id).is_empty():
		var remaining_count: int = max(_active_cue_count(cue_id) - 1, 0)
		if remaining_count <= 0:
			_active_instances_by_cue.erase(cue_id)
		else:
			_active_instances_by_cue[cue_id] = remaining_count

	_player_metadata.erase(instance_id)

func _metadata_for_player(player: AudioStreamPlayer) -> Dictionary:
	return _player_metadata.get(player.get_instance_id(), {})

func _on_pool_player_finished(player: AudioStreamPlayer) -> void:
	_release_player(player)

func _bus_from_options(options: Dictionary, cue_bus: StringName, default_bus: StringName) -> StringName:
	var bus_name := cue_bus
	if String(bus_name).is_empty():
		bus_name = default_bus
	if options.has("bus"):
		bus_name = StringName(options["bus"])

	return _valid_bus_or_master(bus_name)

func _start_music_stream(track: Resource, stream: AudioStream, fade_seconds: float) -> void:
	var track_id := _resource_string_name(track, "id")
	if stream == null:
		_warn_once(StringName("music_stream:%s" % track_id), "Music track has no stream: %s" % track_id)
		return

	_set_stream_loop(stream, _resource_bool(track, "loop", true))

	var previous_player := _active_music_player()
	var target_player_index := 1 - _active_music_player_index
	var target_player := _music_players[target_player_index]

	if _music_fade_tween != null:
		_music_fade_tween.kill()
		_music_fade_tween = null

	target_player.stop()
	target_player.stream = stream
	target_player.bus = _valid_bus_or_master(_resource_string_name(track, "bus", BUS_MUSIC))
	target_player.pitch_scale = 1.0
	var target_volume_db := _resource_float(track, "volume_db", 0.0)
	target_player.volume_db = SILENT_VOLUME_DB if fade_seconds > 0.0 else target_volume_db
	_music_player_loop_flags[target_player.get_instance_id()] = _resource_bool(track, "loop", true)
	target_player.play()

	_active_music_player_index = target_player_index
	_current_music_id = track_id
	_current_music_track = track
	_reset_playlist_schedule(track)

	if fade_seconds > 0.0:
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(target_player, "volume_db", target_volume_db, fade_seconds)
		if previous_player != null and previous_player != target_player and previous_player.playing:
			_music_fade_tween.parallel().tween_property(previous_player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
			_music_fade_tween.tween_callback(_stop_music_player.bind(previous_player))
	else:
		target_player.volume_db = target_volume_db
		if previous_player != null and previous_player != target_player:
			_stop_music_player(previous_player)

func _can_continue_current_music(active_player: AudioStreamPlayer, stream: AudioStream) -> bool:
	return active_player != null and active_player.playing and _is_same_audio_stream(active_player.stream, stream)

func _continue_current_music(track: Resource, active_player: AudioStreamPlayer, fade_seconds: float) -> void:
	if _music_fade_tween != null:
		_music_fade_tween.kill()
		_music_fade_tween = null

	_current_music_id = _resource_string_name(track, "id")
	_current_music_track = track
	_reset_playlist_schedule(track)
	active_player.bus = _valid_bus_or_master(_resource_string_name(track, "bus", BUS_MUSIC))
	_music_player_loop_flags[active_player.get_instance_id()] = _resource_bool(track, "loop", true)

	var target_volume_db := _resource_float(track, "volume_db", 0.0)
	if fade_seconds > 0.0 and not is_equal_approx(active_player.volume_db, target_volume_db):
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(active_player, "volume_db", target_volume_db, fade_seconds)
	else:
		active_player.volume_db = target_volume_db

func _stream_for_track(track: Resource) -> AudioStream:
	if not String(_current_music_state_id).is_empty():
		var variant: Resource = _track_state_variant(track, _current_music_state_id)
		if variant != null:
			var variant_stream := _resource_audio_stream_from_id(variant, "stream_id", "stream")
			if variant_stream != null:
				return variant_stream

	var playlist_streams := _track_playlist_streams(track)
	if not playlist_streams.is_empty():
		return _choose_playlist_stream(track, null)

	return _resource_audio_stream_from_id(track, "base_stream_id", "base_stream")

func _try_apply_pending_music_state() -> void:
	if String(_pending_music_state_id).is_empty() or _pending_music_state_id == _current_music_state_id:
		return

	if String(_current_music_id).is_empty():
		_current_music_state_id = _pending_music_state_id
		_pending_music_state_id = &""
		_music_state_started_msec = Time.get_ticks_msec()
		_music_state_hold_seconds = 0.0
		return

	var track: Resource = _music_tracks.get(_current_music_id, null) as Resource
	if track == null:
		return

	var variant: Resource = _track_state_variant(track, _pending_music_state_id)
	if variant == null:
		_current_music_state_id = _pending_music_state_id
		_pending_music_state_id = &""
		_music_state_started_msec = Time.get_ticks_msec()
		_music_state_hold_seconds = 0.0
		return

	if not _can_leave_current_music_state():
		return

	_current_music_state_id = _resource_string_name(variant, "state_id")
	_pending_music_state_id = &""
	_music_state_started_msec = Time.get_ticks_msec()
	_music_state_hold_seconds = max(_resource_float(variant, "min_hold_seconds", 1.0), 0.0)

	var fade_seconds := _resource_float(variant, "fade_seconds", -1.0)
	if fade_seconds < 0.0:
		fade_seconds = _default_music_switch_fade_seconds(track)
	_start_music_stream(track, _resource_audio_stream_from_id(variant, "stream_id", "stream"), fade_seconds)

func _can_leave_current_music_state() -> bool:
	if _music_state_hold_seconds <= 0.0:
		return true

	var elapsed_seconds := float(Time.get_ticks_msec() - _music_state_started_msec) / 1000.0
	return elapsed_seconds >= _music_state_hold_seconds

func _stop_music_player(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null
	player.volume_db = SILENT_VOLUME_DB
	_music_player_loop_flags.erase(player.get_instance_id())

func _clear_audio_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
	player.stream = null
	_music_player_loop_flags.erase(player.get_instance_id())

func _active_music_player() -> AudioStreamPlayer:
	if _music_players.is_empty():
		return null

	return _music_players[_active_music_player_index]

func _create_music_players() -> void:
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%s" % (index + 1)
		player.bus = BUS_MUSIC
		player.volume_db = SILENT_VOLUME_DB
		player.finished.connect(_on_music_player_finished.bind(player))
		add_child(player)
		_music_players.append(player)

func _create_player_pool(
	pool: Array[AudioStreamPlayer],
	size: int,
	bus_name: StringName,
	player_name_prefix: String
) -> void:
	for index in range(size):
		var player := AudioStreamPlayer.new()
		player.name = "%s%s" % [player_name_prefix, index + 1]
		player.bus = bus_name
		player.finished.connect(_on_pool_player_finished.bind(player))
		add_child(player)
		pool.append(player)

func _ensure_runtime_buses() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_UI)

func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus(AudioServer.get_bus_count())
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, BUS_MASTER)

func _valid_bus_or_master(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name

	_warn_once(StringName("bus:%s" % bus_name), "Audio bus does not exist, falling back to Master: %s" % bus_name)
	return BUS_MASTER

func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	for property_info in stream.get_property_list():
		var property_name := str(property_info.get("name", ""))
		if property_name == "loop":
			stream.set(property_name, should_loop)

func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if player == null or player != _active_music_player():
		return
	if not bool(_music_player_loop_flags.get(player.get_instance_id(), false)):
		return
	if String(_current_music_id).is_empty() or player.stream == null:
		return
	if _track_playlist_streams(_current_music_track).size() > 1:
		_crossfade_to_next_playlist_stream(_random_playlist_crossfade_seconds(_current_music_track))
		return

	player.play()

func _should_suppress_playback() -> bool:
	return DisplayServer.get_name() == "headless"

func _cue_streams(cue: Resource) -> Array:
	if cue == null:
		return []

	var streams: Array[AudioStream] = []
	for stream_id in _raw_stream_ids(cue, "stream_ids"):
		var stream := _audio_registry.get_stream(stream_id)
		if stream == null:
			_warn_once(
				StringName("cue_stream_id:%s" % stream_id),
				"Audio cue references an unregistered stream id: %s" % stream_id
			)
			continue
		streams.append(stream)

	streams.append_array(_raw_audio_streams(cue, "streams"))
	return streams

func _track_state_variant(track: Resource, state_id: StringName) -> Resource:
	if track == null:
		return null
	if track.has_method("get_state_variant"):
		return track.call("get_state_variant", state_id) as Resource

	var raw_variants: Variant = track.get("state_variants")
	if raw_variants is Array:
		for raw_variant in raw_variants:
			var variant: Resource = raw_variant as Resource
			if variant != null and _resource_string_name(variant, "state_id") == state_id:
				return variant

	return null

func _update_music_playlist() -> void:
	if _playlist_crossfade_started or _current_music_track == null:
		return

	var playlist_streams := _track_playlist_streams(_current_music_track)
	if playlist_streams.size() <= 1:
		return

	var active_player := _active_music_player()
	if active_player == null or not active_player.playing or active_player.stream == null:
		return

	var stream_length := active_player.stream.get_length()
	if stream_length <= 0.0:
		return

	var remaining_seconds := stream_length - active_player.get_playback_position()
	if remaining_seconds <= _playlist_next_crossfade_seconds:
		_playlist_crossfade_started = true
		_crossfade_to_next_playlist_stream(_playlist_next_crossfade_seconds)

func _crossfade_to_next_playlist_stream(fade_seconds: float) -> void:
	if _current_music_track == null:
		return

	var active_player := _active_music_player()
	var current_stream := active_player.stream if active_player != null else null
	var next_stream := _choose_playlist_stream(_current_music_track, current_stream)
	if next_stream == null:
		return

	if _is_same_audio_stream(current_stream, next_stream):
		if active_player != null:
			active_player.play()
			_playlist_crossfade_started = false
		return

	_start_music_stream(_current_music_track, next_stream, fade_seconds)

func _reset_playlist_schedule(track: Resource) -> void:
	_playlist_crossfade_started = false
	if _track_playlist_streams(track).size() <= 1:
		_playlist_next_crossfade_seconds = 0.0
		return

	_playlist_next_crossfade_seconds = _random_playlist_crossfade_seconds(track)

func _random_playlist_crossfade_seconds(track: Resource) -> float:
	var minimum_seconds := _resource_float(track, "playlist_crossfade_min_seconds", 5.0)
	var maximum_seconds := _resource_float(track, "playlist_crossfade_max_seconds", 10.0)
	var low: float = min(minimum_seconds, maximum_seconds)
	var high: float = max(minimum_seconds, maximum_seconds)
	if is_equal_approx(low, high):
		return max(low, 0.0)

	return max(_rng.randf_range(low, high), 0.0)

func _track_playlist_streams(track: Resource) -> Array:
	if track == null:
		return []

	var streams: Array[AudioStream] = []
	for stream_id in _raw_stream_ids(track, "playlist_stream_ids"):
		var stream := _audio_registry.get_stream(stream_id)
		if stream == null:
			_warn_once(
				StringName("playlist_stream_id:%s" % stream_id),
				"Music playlist references an unregistered stream id: %s" % stream_id
			)
			continue
		streams.append(stream)

	streams.append_array(_raw_audio_streams(track, "playlist_streams"))
	return streams

func _choose_playlist_stream(track: Resource, previous_stream: AudioStream) -> AudioStream:
	var streams := _track_playlist_streams(track)
	if streams.is_empty():
		return null

	var candidates: Array[AudioStream] = []
	var avoid_repeats := _resource_bool(track, "avoid_immediate_repeats", true)
	for raw_stream in streams:
		var stream := raw_stream as AudioStream
		if stream == null:
			continue
		if avoid_repeats and streams.size() > 1 and _is_same_audio_stream(stream, previous_stream):
			continue
		candidates.append(stream)

	if candidates.is_empty():
		return streams[0] as AudioStream
	if _resource_bool(track, "randomize_playlist", false):
		return candidates[_rng.randi_range(0, candidates.size() - 1)]

	if previous_stream == null:
		return candidates[0]

	var previous_index := -1
	for index in range(streams.size()):
		if _is_same_audio_stream(streams[index] as AudioStream, previous_stream):
			previous_index = index
			break

	var next_index := (previous_index + 1) % streams.size()
	return streams[next_index] as AudioStream

func _track_default_fade_seconds(track: Resource) -> float:
	return _resource_float(track, "default_fade_seconds", 0.75)

func _default_music_switch_fade_seconds(track: Resource) -> float:
	return max(_track_default_fade_seconds(track), DEFAULT_SWITCH_FADE_SECONDS)

func _resource_audio_stream_from_id(resource: Resource, stream_id_field: String, fallback_stream_field: String) -> AudioStream:
	if resource == null:
		return null

	var stream_id := _resource_string_name(resource, stream_id_field)
	if not String(stream_id).is_empty():
		var stream := _audio_registry.get_stream(stream_id)
		if stream != null:
			return stream
		_warn_once(
			StringName("stream_id:%s" % stream_id),
			"Audio resource references an unregistered stream id: %s" % stream_id
		)

	return resource.get(fallback_stream_field) as AudioStream

func _raw_stream_ids(resource: Resource, field_name: String) -> Array[StringName]:
	var stream_ids: Array[StringName] = []
	if resource == null:
		return stream_ids

	var raw_ids: Variant = resource.get(field_name)
	if raw_ids is Array:
		for raw_id in raw_ids:
			var stream_id := _canonical_audio_id(StringName(raw_id))
			if not String(stream_id).is_empty():
				stream_ids.append(stream_id)

	return stream_ids

func _raw_audio_streams(resource: Resource, field_name: String) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	if resource == null:
		return streams

	var raw_streams: Variant = resource.get(field_name)
	if raw_streams is Array:
		for raw_stream in raw_streams:
			var stream := raw_stream as AudioStream
			if stream != null:
				streams.append(stream)

	return streams

func _canonical_audio_id(id: StringName) -> StringName:
	var current_id := StringName(id)
	var visited_ids: Dictionary = {}
	while LEGACY_ID_ALIASES.has(current_id) and not visited_ids.has(current_id):
		visited_ids[current_id] = true
		current_id = StringName(LEGACY_ID_ALIASES[current_id])

	return current_id

func _is_same_audio_stream(left_stream: AudioStream, right_stream: AudioStream) -> bool:
	if left_stream == null or right_stream == null:
		return false
	if left_stream == right_stream:
		return true
	if not left_stream.resource_path.is_empty() and left_stream.resource_path == right_stream.resource_path:
		return true

	return false

func _resource_string_name(resource: Resource, field_name: String, default_value: StringName = &"") -> StringName:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return default_value

func _resource_float(resource: Resource, field_name: String, default_value: float) -> float:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value

func _resource_int(resource: Resource, field_name: String, default_value: int) -> int:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is int or value is float:
		return int(value)

	return default_value

func _resource_bool(resource: Resource, field_name: String, default_value: bool) -> bool:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is bool:
		return value

	return default_value

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _warn_once(key: StringName, message: String) -> void:
	if _missing_warnings.has(key):
		return

	_missing_warnings[key] = true
	push_warning(message)
