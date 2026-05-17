---
title: Scene routes
page-type: reference
status: draft
---

Scene routes are string refs resolved by `GameManager.scene_path_for()` and loaded by `GameManager.go_to_scene()`. Route changes do not automatically change music; scene scripts or run events request music explicitly.

## Metadata

| Item | Value |
| --- | --- |
| Route owner | `res://core/game_manager.gd` |
| Root | `res://scenes` |
| Scene naming | Scene files use PascalCase; scene scripts remain snake_case. |
| Extension behavior | Adds `.tscn` if the ref has no extension. |
| Accepted input | Relative route, `scenes/...`, or full `res://...` path. |

## Current routes

| Route ref | Resolved scene | Main script | Explicit music |
| --- | --- | --- | --- |
| `main_menu` | `res://scenes/ui/main_menu/MainMenu.tscn` | `res://scenes/ui/main_menu/main_menu.gd` | `music.main_menu` |
| `waiting_room` | `res://scenes/ui/waiting_room/WaitingRoom.tscn` | `res://scenes/ui/waiting_room/waiting_room.gd` | `music.waiting_room` |
| `dungeon` | `res://scenes/dungeon/DungeonMap.tscn` | `res://scenes/dungeon/dungeon_controller.gd` | Run start plays `music.dungeon` |
| `combat/BattleScene` | `res://scenes/combat/BattleScene.tscn` | `res://scenes/combat/battle_scene.gd` | Keeps current run music unless an event overrides it |
| `run_summary` | `res://scenes/ui/run_summary/RunSummary.tscn` | `res://scenes/ui/run_summary/run_summary.gd` | Keeps current music until returning to setup |

## Reusable scene fragments

These are real scenes but are not direct route targets today:

| Scene | Purpose |
| --- | --- |
| `res://scenes/combat/ui/BattleHUD.tscn` | Battle HUD instance used inside `BattleScene`; embeds `GlobalHUD` for combat. |
| `res://scenes/combat/ui/CombatantDisplay.tscn` | Reusable combatant display instanced by `BattleScene` for player and enemy combatants. |
| `res://scenes/ui/global_hud/GlobalHUD.tscn` | Persistent run HUD layer instantiated by route scenes or embedded by `BattleHUD`. |
| `res://scenes/combatants/characters/warrior/WarriorBattleVisual.tscn` | Player battle visual loaded through the warrior profile's `battle_visual_scene`. |
| `res://scenes/combatants/enemies/training_ghoul/TrainingGhoulBattleVisual.tscn` | Enemy battle visual loaded through the enemy profile's `battle_visual_scene`. |

`BattleScene.tscn` contains runtime roots for instantiated combatants/displays plus authored invisible placement markers under `PlayerSlots` and `EnemySlots`. Current runtime uses `PlayerSlot1` for the local player, `PlayerSlot2/3` for combat-only AI player copies, and generated `enemy_instances[].position_id` values for enemy displays.

## Route call sites

| Caller | Route |
| --- | --- |
| `main_menu.gd` | `waiting_room` |
| `waiting_room.gd` | `dungeon`, `main_menu` |
| `dungeon_controller.gd` | Starts combat through `GameManager.start_combat()`; summary route on terminal result. |
| `GameManager.start_combat()` | `combat/BattleScene` |
| `GameManager.complete_combat()` | `dungeon` |
| `GameManager.end_current_run()` | `run_summary` |
| `run_summary.gd` | `waiting_room` |

## Examples

```gdscript
GameManager.go_to_scene("dungeon")
GameManager.go_to_scene("combat/BattleScene")
GameManager.go_to_scene("res://scenes/ui/run_summary/RunSummary.tscn")
```

## See also

- [[Run flow]]
- [[Adding a scene route]]
- [[Autoload APIs]]
- [[Audio flow]]
