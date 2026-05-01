---
title: Audio IDs
page-type: reference
status: draft
---

Audio IDs are stable `StringName`s used by `SoundManager` to find scanned streams, cues, and music tracks.

## Authored cue IDs

| ID | Type | Source |
| --- | --- | --- |
| `ui.button.click` | UI cue | `res://assets/audio/common_audio_library.tres` |
| `sfx.global.death.run_ends_loop` | SFX cue | `res://assets/audio/common_audio_library.tres` |
| `sfx.global.boss.boss_start_fight` | SFX cue | `res://assets/audio/common_audio_library.tres` |

## Authored music track IDs

| ID | Base stream | Notes |
| --- | --- | --- |
| `music.main_menu` | `music.bgtheme` | Main menu and run summary. |
| `music.waiting_room` | `music.bgtheme` | Waiting room. |
| `music.dungeon` | `music.dungeon.eerie_exploration` | Uses randomized dungeon playlist. |
| `music.combat` | `music.bgtheme` | Registered but current route mapping sends battle scene to `music.dungeon`. |

## Scanned stream IDs

`AudioRegistry.stream_id_for_path()` derives these from `res://assets/audio`:

| Stream ID | Source file |
| --- | --- |
| `music.bgtheme` | `res://assets/audio/music/bgtheme.wav` |
| `music.dungeon.cautious_battle` | `res://assets/audio/music/dungeon/cautious_battle.wav` |
| `music.dungeon.dramtic_battle` | `res://assets/audio/music/dungeon/dramtic_battle.wav` |
| `music.dungeon.eerie_exploration` | `res://assets/audio/music/dungeon/eerie_exploration.wav` |
| `music.dungeon.impending_doom` | `res://assets/audio/music/dungeon/impending_doom.wav` |
| `music.stems.ambience.01_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://assets/audio/music/stems/ambience/01 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `music.stems.ambience.02_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://assets/audio/music/stems/ambience/02 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `music.stems.ambience.03_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://assets/audio/music/stems/ambience/03 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `music.stems.ambience.04_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://assets/audio/music/stems/ambience/04 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `sfx.global.boss.boss_start_fight` | `res://assets/audio/sfx/global/boss/BossStartFight.wav` |
| `sfx.global.death.run_ends_loop` | `res://assets/audio/sfx/global/death/RunEndsLoop.wav` |
| `ui.button.click` | `res://assets/audio/ui/button/Click.wav` |
| `ui.notification.skill_tree_point` | `res://assets/audio/ui/notification/SkillTreePoint.wav` |

## ID rules

`SoundManager` no longer canonicalizes legacy shorthand IDs. Call sites should use the exact cue, track, or stream ID derived from the current path or declared in `common_audio_library.tres`.

## See also

- [[Audio flow]]
- [[Adding audio]]
- [[Autoload APIs]]
- [[Resource inventory]]
