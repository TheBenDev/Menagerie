---
title: Start here
page-type: navigation
status: draft
---

Menagerie is a Godot 4.6 project where core runtime logic lives in `res://core`, scene-local behavior and combatant-specific classes live in `res://scenes`, and source assets live in `res://assets`.

This documentation follows an MDN-style split:

- Navigation pages explain where to go next.
- Guides explain how to complete a task.
- Reference pages describe the details of a script, route, resource, signal, or data contract.

## Project facts

| Item | Value |
| --- | --- |
| Godot version | Godot 4.6 project, validated with `Godot_v4.6.2-stable_win64_console.exe` |
| Main scene | `res://scenes/ui/main_menu/main_menu.tscn` |
| Core autoloads | `SoundManager`, `GameManager` |
| Editor plugins | Easy State Machine, Godot AI |
| Script count | 60 `.gd` files |
| Data resource count | 16 `.tres` files under `res://core`, `res://scenes/combatants`, and `res://assets/audio` |
| Real scene count | 9 `.tscn` scenes, excluding editor `.tmp` scene files |

## Folder map

| Folder                            | Purpose                                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `res://core`                      | Shared runtime systems, combat logic, resource classes, difficulty/status/reward data, and autoload support. |
| `res://scenes`                    | Route targets, UI scene scripts, combatant folders, and scene-local behavior.                                |
| `res://scenes/combatants`         | Shared combatant classes plus character/enemy-specific profiles, visuals, actions, and AI data.              |
| `res://assets`                    | UI, font, and imported source assets.                                                                        |
| `res://assets/audio`              | Music and SFX source files scanned into stable audio IDs, plus the authored audio library resource.          |
| `! Menagerie Wiki/Core Mechanics` | Design and mechanics notes. Keep developer docs out of this folder.                                          |

## First files to read

Read these in order when learning the runtime:

1. `res://project.godot` - autoloads, main scene, plugins, display defaults.
2. `res://core/game_manager.gd` - run setup, scene routing, rewards, timers, and scene music.
3. `res://core/run_data.gd` - mutable run state and combat result aggregation.
4. `res://scenes/dungeon/dungeon_controller.gd` - map progression and fight selection.
5. `res://scenes/combat/battle_scene.gd` - battle scene coordinator.
6. `res://core/combat/battle/battle_controller.gd` - combat time, action queue, and turn/request loop.
7. `res://scenes/combatants/combatant.gd` - stats, HP, block, statuses, action state, and damage handling.
8. `res://core/combat/actions/combat_effect_library.gd` - namespaced effect IDs and shared effect behavior.
9. `res://core/audio/sound_manager.gd` - audio cue catalog, auto-scanned streams, music, and SFX.
10. `res://scenes/combat/ui/battle_hud.gd` - player-facing battle controls and panels.

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
rg --files core scenes assets -g '!*.uid' -g '!*.tmp' -g '!*.import'
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
