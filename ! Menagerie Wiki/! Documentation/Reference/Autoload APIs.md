---
title: Autoload APIs
page-type: reference
status: draft
---

Autoloads are the closest thing this project has to global service endpoints.

## Metadata

| Autoload | Source | Purpose |
| --- | --- | --- |
| `GameManager` | `res://core/game_manager.gd` | Run setup, scene routing, rewards, timers, and explicit music routing. |
| `SoundManager` | `res://core/audio/sound_manager.gd` | Audio cue catalog, SFX/UI playback, music, buses, and audio debug data. |
| `_mcp_game_helper` | `res://addons/godot_ai/runtime/game_helper.gd` | Godot AI MCP runtime helper. Do not document as project gameplay API. |

## GameManager

### Signals

| Signal | Payload | Meaning |
| --- | --- | --- |
| `run_time_changed` | `remaining_time_seconds: float`, `max_time_seconds: float` | Run timer changed or was reset. |
| `run_currencies_changed` | `memories: int`, `gold: int` | Run currency totals changed. |
| `run_ended` | `reason: String` | Current run ended with `victory`, `defeat`, or `timeout`. |

### Public methods

| Method | Returns | Use |
| --- | --- | --- |
| `start_new_run(character, difficulty, dungeon_seed := "", dungeon_floor_layer := 1)` | `Variant` | Creates a fresh `RunData`, applies selection, resolves/stores a dungeon seed, applies it to global gameplay RNG, generates the dungeon map, emits run HUD state, and starts run music. |
| `clear_run()` | `void` | Clears `current_run_data`. |
| `start_combat(node_id, node_type, enemy_profile_path, is_boss)` | `void` | Stores encounter data, advances travel time, routes to `combat/BattleScene`. |
| `complete_combat(result)` | `void` | Stores a pending combat result and routes back to `dungeon`. |
| `consume_last_combat_result()` | `Variant` | Returns and clears the pending result. |
| `has_pending_combat_result()` | `bool` | Checks whether dungeon should apply a completed combat result. |
| `advance_run_time(seconds)` | `bool` | Advances the run timer and ends the run on timeout. |
| `get_dungeon_encounter(encounter_id)` | `Resource` | Resolves an authored dungeon encounter from the default encounter pool. |
| `get_dungeon_encounter_scene(encounter_id)` | `PackedScene` | Resolves the presentation scene for an encounter ID. |
| `apply_dungeon_encounter_result(encounter_id, result)` | `Dictionary` | Applies a completed encounter scene result to run HP/stat state. |
| `apply_run_player_state_to_combatant(combatant)` | `void` | Copies effective run stats onto the player combatant before combat starts. |
| `get_run_player_hp_snapshot()` | `Dictionary` | Returns persistent player HP as `{current, max}`. |
| `get_effective_player_stats()` | `Dictionary` | Returns selected character stats after run modifiers. |
| `grant_run_rewards(reward_result)` | `void` | Adds memory and gold from a reward dictionary or result-like object. |
| `end_current_run(reason)` | `void` | Ends the run, emits state/signals, and defers routing to summary. |
| `emit_run_state()` | `void` | Emits timer and currency signals for current or empty state. |
| `export_current_run_memories()` | `int` | Exports earned memories into `pending_class_memory_awards` once. |
| `calculate_rewards_for_profile(profile, is_boss)` | `Dictionary` | Calculates memory/gold from reward profile, difficulty, and boss multiplier. |
| `get_selected_difficulty_profile()` | `Resource` | Loads the selected difficulty resource. |
| `get_selected_character_profile()` | `CombatantProfile` | Loads the selected character profile. |
| `get_selected_character_id()` | `String` | Gets current or setup character ID. |
| `get_selected_difficulty_id()` | `String` | Gets current or setup difficulty ID. |
| `get_selected_difficulty_profile_path()` | `String` | Gets selected difficulty resource path. |
| `get_selected_difficulty_display_name()` | `String` | Gets selected difficulty display name. |
| `get_current_encounter()` | `Dictionary` | Gets current encounter route data with fallback enemy profile. |
| `go_to_scene(scene_ref)` | `void` | Resolves and changes scenes without changing music. |
| `play_music_for_scene(scene_ref)` | `void` | Applies the route-to-music mapping without changing scenes. |
| `play_run_music(restart := false)` | `void` | Starts or resumes the dungeon run playlist. |
| `scene_path_for(scene_ref)` | `String` | Normalizes route refs to `res://scenes/... .tscn` paths. |

### Data contracts

`get_current_encounter()` returns:

| Key | Type | Meaning |
| --- | --- | --- |
| `node_id` | `int` | Dungeon node ID, or `-1` when unset. |
| `node_type` | `String` | `Fight`, `Boss`, `Haven`, or empty. |
| `enemy_profile_path` | `String` | Enemy profile `.tres`, falling back to Training Ghoul. |
| `is_boss` | `bool` | Whether boss overrides/rewards apply. |

`calculate_rewards_for_profile()` returns:

| Key | Type | Meaning |
| --- | --- | --- |
| `memories_awarded` | `int` | Rounded non-negative memory reward. |
| `gold_awarded` | `int` | Rounded non-negative gold reward. |

`apply_dungeon_encounter_result()` accepts a result dictionary from an encounter scene:

| Key | Type | Meaning |
| --- | --- | --- |
| `mode` | `String` | Currently supports `complete`. Other modes are reserved. |
| `choice_index` | `int` | Zero-based index of the selected inline choice dictionary. |

## SoundManager

### Public methods

| Method | Returns | Use |
| --- | --- | --- |
| `load_library(library_path)` | `void` | Loads an `AudioLibraryData` resource and resets the catalog. |
| `set_library(new_library)` | `void` | Uses an already-loaded audio library resource. |
| `play_sfx(id, options := {})` | `void` | Plays a cue through the SFX pool. |
| `play_ui(id, options := {})` | `void` | Plays a cue through the UI pool. |
| `play_music(id, fade_seconds := -1.0, restart := false)` | `void` | Crossfades or continues a registered music track. |
| `stop_music(fade_seconds := 2.0)` | `void` | Stops active music with optional fade. |
| `set_music_state(state_id, intensity := 0.0)` | `void` | Requests an adaptive state variant for current music. |
| `set_bus_volume(bus_name, linear_value)` | `void` | Sets and mutes/unmutes a bus using a 0.0-1.0 value. |
| `get_current_music_id()` | `StringName` | Returns current music track ID. |
| `get_current_music_state_id()` | `StringName` | Returns current adaptive music state ID. |
| `is_music_playing()` | `bool` | Checks if any music player is active. |
| `has_audio_stream(id)` | `bool` | Checks if the scanned registry contains a stream ID. Streams are loaded lazily when played. |
| `get_registered_audio_stream_ids()` | `Array[StringName]` | Lists scanned audio stream IDs without forcing stream loads. |
| `get_music_debug_state()` | `Dictionary` | Returns registry, track, bus, and player debug data. |

### Cue options

`play_sfx()` and `play_ui()` accept:

| Option | Type | Meaning |
| --- | --- | --- |
| `priority` | `int` | Overrides cue priority for player stealing and max-instance handling. |
| `bus` | `StringName` or `String` | Overrides cue bus if it exists. |
| `volume_db` | `float` | Adds to authored cue volume. |
| `pitch_scale` | `float` | Multiplies randomized cue pitch. |

## Examples

```gdscript
GameManager.start_new_run("Warrior", "normal", "debug-seed")
GameManager.go_to_scene("dungeon")
```

```gdscript
SoundManager.play_sfx(&"sfx.global.boss.boss_start_fight", {"priority": 7})
SoundManager.play_music(&"music.dungeon")
SoundManager.set_music_state(&"combat_tense", 0.5)
```

## See also

- [[Run flow]]
- [[Audio flow]]
- [[Scene routes]]
- [[Signals and events]]
- [[Audio IDs]]
