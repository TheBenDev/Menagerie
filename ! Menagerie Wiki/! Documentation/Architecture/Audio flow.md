---
title: Audio flow
page-type: guide
status: draft
---

Audio is driven by a `SoundManager` autoload that scans `res://assets/audio`, merges authored cue overrides, and exposes stable SFX/UI/music calls.

## Main actors

| Actor | Source | Responsibility |
| --- | --- | --- |
| `SoundManager` | `res://core/audio/sound_manager.gd` | Autoload for cue registration, SFX/UI playback, music crossfades, buses, and debug state. |
| `AudioRegistry` | `res://core/audio/audio_registry.gd` | Scans sound files and derives stable stream IDs from paths. |
| `AudioLibraryData` | `res://core/audio/audio_library_data.gd` | Resource catalog for authored cues and music tracks. |
| `AudioCueData` | `res://core/audio/audio_cue_data.gd` | SFX/UI cue settings such as bus, volume, pitch, cooldown, instances, and priority. |
| `MusicTrackData` | `res://core/audio/music_track_data.gd` | Music base stream, playlists, state variants, bus, volume, fade, and loop behavior. |
| `MusicStateData` | `res://core/audio/music_state_data.gd` | Adaptive music state stream and fade behavior. |
| `CombatAudioBridge` | `res://core/audio/combat_audio_bridge.gd` | Converts combat events into SFX and adaptive combat music states. |

## Startup flow

1. `project.godot` autoloads `SoundManager`.
2. `SoundManager._ready()` ensures runtime buses, creates player pools, scans `res://assets/audio`, loads `res://assets/audio/common_audio_library.tres`, and connects existing/new buttons.
3. `AudioRegistry.scan()` maps sound paths to normalized stream IDs.
4. `SoundManager._register_scanned_cues()` creates default cues for scanned streams.
5. Authored `AudioCueData` and `MusicTrackData` override or extend the scanned catalog.

## Playback flow

- UI buttons are automatically connected to `ui.button.click`.
- Gameplay scripts call `SoundManager.play_sfx(id, options)`.
- Scene routing calls `GameManager.play_music_for_scene(scene_ref)`, which maps route IDs to music IDs.
- Combat uses `CombatAudioBridge.setup(battle, player, enemy, is_boss)` and listens for action, HP, block, death, time, and queue signals.

## Music route mapping

| Scene ID | Music ID |
| --- | --- |
| `main_menu` | `music.main_menu` |
| `waiting_room` | `music.waiting_room` |
| `dungeon` | `music.dungeon` |
| `battle/battlescene` | `music.dungeon` |
| `run_summary` | `music.main_menu` |

## Adaptive combat states

`CombatAudioBridge` sends these state IDs to `SoundManager.set_music_state()`:

| State | Trigger |
| --- | --- |
| `combat_base` | Low intensity. |
| `combat_tense` | Intensity at least `0.35`. |
| `combat_critical` | Player HP at or below 25%, or intensity at least `0.7`. |

## See also

- [[Audio IDs]]
- [[Autoload APIs]]
- [[Adding audio]]
- [[Signals and events]]
