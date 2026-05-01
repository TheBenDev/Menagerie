---
title: Scene routes
page-type: reference
status: draft
---

Scene routes are string refs resolved by `GameManager.scene_path_for()` and loaded by `GameManager.go_to_scene()`.

## Metadata

| Item | Value |
| --- | --- |
| Route owner | `res://core/game_manager.gd` |
| Root | `res://scenes` |
| Extension behavior | Adds `.tscn` if the ref has no extension. |
| Accepted input | Relative route, `scenes/...`, or full `res://...` path. |

## Current routes

| Route ref | Resolved scene | Main script | Music mapping |
| --- | --- | --- | --- |
| `main_menu` | `res://scenes/ui/main_menu/main_menu.tscn` | `res://scenes/ui/main_menu/main_menu.gd` | `music.main_menu` |
| `waiting_room` | `res://scenes/ui/waiting_room/waiting_room.tscn` | `res://scenes/ui/waiting_room/waiting_room.gd` | `music.waiting_room` |
| `dungeon` | `res://scenes/dungeon/dungeon.tscn` | `res://scenes/dungeon/dungeon_controller.gd` | `music.dungeon` |
| `Battle/BattleScene` | `res://scenes/combat/BattleScene.tscn` | `res://scenes/combat/battle_scene.gd` | `music.dungeon` |
| `run_summary` | `res://scenes/ui/run_summary/run_summary.tscn` | `res://scenes/ui/run_summary/run_summary.gd` | `music.main_menu` |

## Reusable scene fragments

These are real scenes but are not direct route targets today:

| Scene | Purpose |
| --- | --- |
| `res://scenes/combat/ui/BattleHUD.tscn` | Battle HUD instance used inside `BattleScene`. |
| `res://scenes/ui/global_hud/GlobalHUD.tscn` | Persistent run HUD layer instantiated by route scenes. |
| `res://scenes/combatants/characters/warrior/WarriorBattleVisual.tscn` | Player battle visual used by the battle HUD. |
| `res://scenes/combatants/enemies/training_ghoul/TrainingGhoulBattleVisual.tscn` | Enemy battle visual used by the battle HUD. |

## Route call sites

| Caller | Route |
| --- | --- |
| `main_menu.gd` | `waiting_room` |
| `waiting_room.gd` | `dungeon`, `main_menu` |
| `dungeon_controller.gd` | Starts combat through `GameManager.start_combat()`; summary route on terminal result. |
| `GameManager.start_combat()` | `Battle/BattleScene` |
| `GameManager.complete_combat()` | `dungeon` |
| `GameManager.end_current_run()` | `run_summary` |
| `run_summary.gd` | `waiting_room` |

## Examples

```gdscript
GameManager.go_to_scene("dungeon")
GameManager.go_to_scene("Battle/BattleScene")
GameManager.go_to_scene("res://scenes/ui/run_summary/run_summary.tscn")
```

## See also

- [[Run flow]]
- [[Adding a scene route]]
- [[Autoload APIs]]
- [[Audio flow]]
