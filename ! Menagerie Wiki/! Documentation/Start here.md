---
title: Start here
page-type: navigation
status: draft
---

Menagerie is a Godot 4.6 project where runtime logic lives in `res://scripts`, authored gameplay data lives mostly in `res://data`, and scenes live in `res://scenes`.

This documentation follows an MDN-style split:

- Navigation pages explain where to go next.
- Guides explain how to complete a task.
- Reference pages describe the details of a script, route, resource, signal, or data contract.

## Project facts

| Item | Value |
| --- | --- |
| Godot version | Godot 4.6 project, validated with `Godot_v4.6.2-stable_win64_console.exe` |
| Main scene | `res://scenes/main_menu.tscn` |
| Core autoloads | `SoundManager`, `GameManager` |
| Editor plugins | Easy State Machine, Godot AI |
| Script count | 55 `.gd` files |
| Data resource count | 13 `.tres` files under `res://data` |
| Real scene count | 9 `.tscn` scenes, excluding editor `.tmp` scene files |

## Folder map

| Folder                            | Purpose                                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `res://scripts/audio`             | Audio registry, playback service, and combat-to-audio bridge.                                                |
| `res://scripts/combat`            | Battle orchestration, combatants, timeline, action resolution, enemy AI, damage packets, and combat results. |
| `res://scripts/data`              | Resource classes used by `.tres` data files.                                                                 |
| `res://scripts/dungeon`           | Dungeon node state, node buttons, and dungeon progression.                                                   |
| `res://scripts/ui`                | Main menu, waiting room, global HUD, battle HUD, shared controls, and run summary.                           |
| `res://data`                      | Authored character, enemy, difficulty, status, reward, audio, and visual state-machine resources.            |
| `res://scenes`                    | Route targets and reusable scene fragments.                                                                  |
| `res://assets`                    | UI, character, enemy, background, and imported asset sources.                                                |
| `res://sounds`                    | Music and SFX source files scanned into stable audio IDs.                                                    |
| `! Menagerie Wiki/Core Mechanics` | Design and mechanics notes. Keep developer docs out of this folder.                                          |

## First files to read

Read these in order when learning the runtime:

1. `res://project.godot` - autoloads, main scene, plugins, display defaults.
2. `res://scripts/game_manager.gd` - run setup, scene routing, rewards, timers, and scene music.
3. `res://scripts/run_data.gd` - mutable run state and combat result aggregation.
4. `res://scripts/dungeon/dungeon_controller.gd` - map progression and fight selection.
5. `res://scripts/combat/battle/battle_scene.gd` - battle scene coordinator.
6. `res://scripts/combat/battle/battle_controller.gd` - combat time, action queue, and turn/request loop.
7. `res://scripts/combat/combatants/combatant.gd` - stats, HP, block, statuses, action state, and damage handling.
8. `res://scripts/combat/actions/combat_effect_library.gd` - namespaced effect IDs and shared effect behavior.
9. `res://scripts/audio/sound_manager.gd` - audio cue catalog, auto-scanned streams, music, and SFX.
10. `res://scripts/ui/battle/battle_hud.gd` - player-facing battle controls and panels.

## Main reading paths

- New to the architecture: [[Run flow]], [[Combat flow]], [[Data and resource model]], [[UI flow]], [[Audio flow]].
- Adding gameplay data: [[Adding a combat action]], [[Adding an enemy]], [[Adding a status or effect]], [[Adding a difficulty]].
- Adding presentation: [[Adding a HUD element]], [[Adding audio]], [[Adding a battle visual]].
- Looking up details: [[Autoload APIs]], [[Scene routes]], [[Script inventory]], [[Resource inventory]], [[Signals and events]], [[Audio IDs]], [[Asset inventory]].
- Browsing sections: [[Architecture index]], [[Reference index]], [[Guides index]], [[Templates index]].

## Maintenance rule

Whenever a public method, signal, exported property, scene route, resource schema, audio ID, or authored data contract changes, update the matching reference page and any guide that uses it.

## Validation

After changing scripts or Godot resources, run:

```powershell
& 'H:\Apps\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

For documentation-only changes, verify inventories with:

```powershell
rg --files scripts data scenes -g '!*.uid' -g '!*.tmp' -g '!*.import'
```

## See also

- [[Run flow]]
- [[Combat flow]]
- [[Architecture index]]
- [[Reference index]]
- [[Guides index]]
- [[Autoload APIs]]
- [[Scene routes]]
- [[Documentation workflow]]
