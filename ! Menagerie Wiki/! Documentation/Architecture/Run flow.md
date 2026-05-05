---
title: Run flow
page-type: guide
status: draft
---

The run flow describes how menu selection becomes dungeon state, combat, rewards, and a final run summary.

## Main actors

| Actor | Source | Responsibility |
| --- | --- | --- |
| `GameManager` | `res://core/game_manager.gd` | Autoload that owns run setup, scene transitions, rewards, timer events, and route music. |
| `RunData` | `res://core/run_data.gd` | RefCounted model for selected character, difficulty, timer, current encounter, rewards, and combat totals. |
| Waiting room | `res://scenes/ui/waiting_room/waiting_room.gd` | Selects character and difficulty, starts a run, routes to dungeon. |
| Dungeon controller | `res://scenes/dungeon/dungeon_controller.gd` | Builds the grid map, applies completed node/combat results, and starts routed encounters. |
| Battle scene | `res://scenes/combat/battle_scene.gd` | Reports combat results back to `GameManager`. |
| Run summary | `res://scenes/ui/run_summary/run_summary.gd` | Displays run totals and exports earned memories. |

## Flow

1. `MainMenu.tscn` calls `GameManager.go_to_scene("waiting_room")`.
2. `waiting_room.gd` calls `GameManager.start_new_run(selected_character, selected_difficulty)`.
3. `GameManager` creates a fresh `RunData`, stores the selected setup, emits run HUD signals, and routes to `dungeon`.
4. `dungeon_controller.gd` creates runtime `DungeonNodeData` from grid descriptors and instantiates `DungeonNodeView` buttons.
5. Haven starts revealed but unvisited. Clicking a reachable node emits a node event through `DungeonNodeEventHelper`.
6. Empty and placeholder event nodes complete immediately unless a route is later added for their event type.
7. Selecting a fight or boss calls `GameManager.start_combat(node_id, node_type, enemy_profile_path, is_boss)`.
8. `GameManager` stores encounter metadata, advances travel time by `RunData.NODE_TRAVEL_TIME_SECONDS`, then routes to `combat/BattleScene`.
9. `battle_scene.gd` loads the encounter profile from `GameManager.get_current_encounter()`, runs combat, and creates a `CombatResult`.
10. `GameManager.complete_combat(result)` stores the result and routes back to `dungeon`.
11. `dungeon_controller.gd` consumes the pending result, updates `RunData`, emits HUD state, and either continues or routes to `run_summary`.
12. `run_summary.gd` shows totals and returns to `waiting_room`.

## End conditions

| End reason | Owner | Trigger |
| --- | --- | --- |
| `victory` | `RunData.register_combat_result()` | Boss combat result is victorious. |
| `defeat` | `BattleScene._finish_combat(false)` then `RunData.register_combat_result()` | Player loses combat. |
| `timeout` | `GameManager.advance_run_time()` or `BattleScene._on_run_ended()` | Remaining run time reaches zero. |

## Key contracts

- `GameManager.current_run_data` is nullable; callers that need state should use `GameManager.start_new_run()` or helper methods that create a default run.
- `GameManager.get_current_encounter()` always returns a dictionary with `node_id`, `node_type`, `enemy_profile_path`, and `is_boss`.
- `RunData.pending_combat_result` is a handoff between `BattleScene` and `DungeonController`.
- `RunData.visited_dungeon_node_ids` is the source of truth for revealed/visited dungeon progression.
- The global HUD listens to `GameManager.run_time_changed` and `GameManager.run_currencies_changed`.

## See also

- [[Autoload APIs]]
- [[Scene routes]]
- [[Signals and events]]
- [[Adding a scene route]]
