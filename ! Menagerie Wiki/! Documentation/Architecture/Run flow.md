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
| `RunData` | `res://core/run_data.gd` | RefCounted model for selected character, party state, dungeon seed/layer, timer, current encounter, rewards, and combat totals. |
| `PlayerPartyState` | `res://core/party/player_party_state.gd` | Run-owned player roster state, active party members, leader, and selected member. |
| `CombatantState` | `res://core/combat/combatant_state.gd` | Persistent run combat state for a party member, including profile path, stats, HP, status map, and modifiers. |
| Waiting room | `res://scenes/ui/waiting_room/waiting_room.gd` | Selects character, difficulty, optional seed, starts a run, routes to dungeon. |
| Dungeon generator | `res://core/dungeon/dungeon_floor_generator.gd` | Builds deterministic dungeon node descriptors from seed, layer, difficulty, and tuning config. |
| Encounter pool | `res://core/dungeon/encounters/default_dungeon_encounter_pool.tres` | Stores weighted encounter events, valid floors, presentation scenes, choices, and run-level effects. |
| Dungeon controller | `res://scenes/dungeon/dungeon_controller.gd` | Generates and builds the grid map, applies completed node/combat results, and starts routed encounters. |
| Battle scene | `res://scenes/combat/battle_scene.gd` | Reports combat results back to `GameManager`. |
| Run summary | `res://scenes/ui/run_summary/run_summary.gd` | Displays run totals and exports earned memories. |

## Flow

1. `MainMenu.tscn` calls `GameManager.go_to_scene("waiting_room")`.
2. `waiting_room.gd` calls `GameManager.start_new_run(selected_character, selected_difficulty, seed_text)`.
3. `GameManager` creates a fresh `RunData`, stores the selected setup, initializes a one-member Warrior `PlayerPartyState`, resolves a replayable dungeon seed, applies it to Godot's global gameplay RNG, generates floor descriptors, sets floor layer `1`, emits run HUD signals, and routes to `dungeon`.
4. `dungeon_controller.gd` reads stored descriptors from `RunData`, creates runtime `DungeonNodeData`, applies explicit descriptor connections, and instantiates `DungeonNodeView` buttons.
5. Haven starts revealed but unvisited. Clicking a reachable node emits a node event through `DungeonNodeEventHelper`.
6. Empty nodes advance run time by `RunData.EMPTY_NODE_TIME_SECONDS`, then complete.
7. Encounter nodes advance run time by `RunData.NODE_TRAVEL_TIME_SECONDS`, load their scene by descriptor `encounter_id`, wait for `encounter_finished`, then apply the selected choice effects to `RunData`.
8. Selecting a fight or boss calls `GameManager.start_combat(node_id, node_type, enemy_profile_path, is_boss)`.
9. `GameManager` stores encounter metadata, advances travel time by `RunData.NODE_TRAVEL_TIME_SECONDS`, then routes to `combat/BattleScene`.
10. `battle_scene.gd` loads the encounter profile from `GameManager.get_current_encounter()`, applies effective Warrior `CombatantState` stats and persistent HP through the existing player bridge, runs combat, and creates a `CombatResult`.
11. `GameManager.complete_combat(result)` stores the result and routes back to `dungeon`.
12. `dungeon_controller.gd` consumes the pending result, updates `RunData`, emits HUD state, and either continues or routes to `run_summary`.
13. `run_summary.gd` shows totals and returns to `waiting_room`.

## End conditions

| End reason | Owner | Trigger |
| --- | --- | --- |
| `victory` | `RunData.register_combat_result()` | Boss combat result is victorious. |
| `defeat` | Encounter damage, `BattleScene._finish_combat(false)`, then `RunData.register_combat_result()` | Persistent player HP reaches zero or player loses combat. |
| `timeout` | `GameManager.advance_run_time()` or `BattleScene._on_run_ended()` | Remaining run time reaches zero. |

## Key contracts

- `GameManager.current_run_data` is nullable; callers that need state should use `GameManager.start_new_run()` or helper methods that create a default run.
- `GameManager.get_current_encounter()` always returns a dictionary with `node_id`, `node_type`, `enemy_profile_path`, and `is_boss`.
- `RunData.dungeon_seed` is the replay value for deterministic dungeon generation and gameplay RNG. Blank waiting-room seed input is resolved before storage.
- `RunData.dungeon_floor_layer` is stored as `1` until multi-floor progression exists.
- `RunData.dungeon_node_descriptors` stores the generated map for the active run so returning from combat does not re-roll or re-consume map generation RNG.
- Encounter descriptors store `encounter_id`, selected from the encounter pool by the seeded generation RNG.
- `RunData.player_party_state` owns the active player roster. Phase 1 creates one active Warrior member with `control_mode = LocalPlayer`.
- Warrior's `CombatantState` is the intended persistent run model for player stats and HP.
- `RunData.player_current_hp`, `player_max_hp`, and `player_base_stats` are compatibility mirrors synchronized with Warrior's `CombatantState` for existing HUD, encounter, and combat call sites.
- `RunData.run_stat_modifiers` stores permanent and run-time-limited stat buffs and is mirrored into Warrior's `CombatantState`. `GameManager.advance_run_time()` ticks temporary modifiers.
- `RunData.pending_combat_result` is a handoff between `BattleScene` and `DungeonController`.
- `RunData.visited_dungeon_node_ids` is the source of truth for revealed/visited dungeon progression.
- Generated descriptors may include `connections`; when omitted, the dungeon controller falls back to old id-order linear connections.
- The global HUD listens to `GameManager.run_time_changed` and `GameManager.run_currencies_changed`.

## See also

- [[Autoload APIs]]
- [[Scene routes]]
- [[Signals and events]]
- [[Adding a scene route]]
