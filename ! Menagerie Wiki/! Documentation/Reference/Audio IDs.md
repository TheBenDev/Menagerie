---
title: Audio IDs
page-type: reference
status: draft
---

Audio IDs are stable `StringName`s used by `SoundManager` to find scanned streams, cues, and music tracks.

## Authored cue IDs

| ID | Type | Source |
| --- | --- | --- |
| `ui.button.click` | UI cue | `res://data/audio/common_audio_library.tres` |
| `sfx.global.death.run_ends_loop` | SFX cue | `res://data/audio/common_audio_library.tres` |
| `sfx.boss.boss_start_fight` | SFX cue | `res://data/audio/common_audio_library.tres` |
| `sfx.enemy.jockey.diddy_jocky` | SFX cue | `res://data/audio/common_audio_library.tres` |

## Authored music track IDs

| ID | Base stream | Notes |
| --- | --- | --- |
| `music.main_menu` | `music.bgtheme` | Main menu and run summary. |
| `music.waiting_room` | `music.bgtheme` | Waiting room. |
| `music.dungeon` | `music.dungeon.eerie_exploration` | Uses randomized dungeon playlist. |
| `music.combat` | `music.bgtheme` | Registered but current route mapping sends battle scene to `music.dungeon`. |

## Scanned stream IDs

`AudioRegistry.stream_id_for_path()` derives these from `res://sounds`:

| Stream ID | Source file |
| --- | --- |
| `music.bgtheme` | `res://sounds/music/bgtheme.wav` |
| `music.dungeon.cautious_battle` | `res://sounds/music/Dungeon/cautious_battle.wav` |
| `music.dungeon.dramtic_battle` | `res://sounds/music/Dungeon/dramtic_battle.wav` |
| `music.dungeon.eerie_exploration` | `res://sounds/music/Dungeon/eerie_exploration.wav` |
| `music.dungeon.impending_doom` | `res://sounds/music/Dungeon/impending_doom.wav` |
| `music.stems.ambience.01_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://sounds/music/Stems/Ambience/01 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `music.stems.ambience.02_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://sounds/music/Stems/Ambience/02 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `music.stems.ambience.03_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://sounds/music/Stems/Ambience/03 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `music.stems.ambience.04_dsgn_dron_dungeon_ambience_drone_dark_loop` | `res://sounds/music/Stems/Ambience/04 DSGNDron, Dungeon, Ambience, Drone, Dark, Loop.wav` |
| `sfx.boss.boss_start_fight` | `res://sounds/sfx/Boss/BossStartFight.wav` |
| `sfx.enemy.jockey.diddy_jocky` | `res://sounds/sfx/Enemy/Jockey/diddy jocky.wav` |
| `sfx.global.death.run_ends_loop` | `res://sounds/sfx/Global/Death/RunEndsLoop.wav` |
| `ui.button.click` | `res://sounds/ui/Button/Click.wav` |
| `ui.notification.skill_tree_point` | `res://sounds/ui/Notification/SkillTreePoint.wav` |

## Legacy aliases

`SoundManager` canonicalizes these older IDs:

| Alias | Canonical ID |
| --- | --- |
| `button_click` | `ui.button.click` |
| `run_ends_loop` | `sfx.global.death.run_ends_loop` |
| `boss_start_fight` | `sfx.boss.boss_start_fight` |
| `diddy_jocky` | `sfx.enemy.jockey.diddy_jocky` |
| `main_menu` | `music.main_menu` |
| `waiting_room` | `music.waiting_room` |
| `dungeon` | `music.dungeon` |
| `combat` | `music.combat` |

## See also

- [[Audio flow]]
- [[Adding audio]]
- [[Autoload APIs]]
- [[Resource inventory]]
