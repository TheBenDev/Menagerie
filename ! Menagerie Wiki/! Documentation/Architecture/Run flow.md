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
| `DungeonMapPawnState` | `res://core/dungeon/dungeon_map_pawn_state.gd` | Persistent run map position, travel orders, and event-lock state for one active party member. |
| Waiting room | `res://scenes/ui/waiting_room/waiting_room.gd` | Selects character, difficulty, optional seed, starts a run, routes to dungeon. |
| Dungeon generator | `res://core/dungeon/dungeon_floor_generator.gd` | Builds deterministic dungeon node descriptors from seed, layer, difficulty, and tuning config. |
| Encounter pool | `res://core/dungeon/encounters/default_dungeon_encounter_pool.tres` | Stores weighted encounter events, valid floors, presentation scenes, choices, and run-level effects. |
| Dungeon controller | `res://scenes/dungeon/dungeon_controller.gd` | Generates and builds the grid map, advances travel playback, applies completed node/combat results, and starts routed encounters. |
| Dungeon movement coordinator | `res://core/dungeon/dungeon_movement_coordinator.gd` | Advances all active pawn travel orders in synchronized node steps. |
| Dungeon pawn view | `res://scenes/dungeon/dungeon_map_pawn_view.gd` | Visual-only marker for one run-owned dungeon pawn. |
| Battle scene | `res://scenes/combat/battle_scene.gd` | Reports combat results back to `GameManager`. |
| Run summary | `res://scenes/ui/run_summary/run_summary.gd` | Displays run totals and exports earned memories. |

## Flow

1. `MainMenu.tscn` calls `GameManager.go_to_scene("waiting_room")`.
2. `waiting_room.gd` calls `GameManager.start_new_run(selected_character, selected_difficulty, seed_text)`.
3. `GameManager` creates a fresh `RunData`, stores the selected setup, initializes a one-member Warrior `PlayerPartyState`, resolves a replayable dungeon seed, applies it to Godot's global gameplay RNG, generates floor descriptors, creates Warrior's dungeon pawn at Haven, seeds revealed/visited node state, emits run HUD signals, and routes to `dungeon`.
4. `dungeon_controller.gd` reads stored descriptors from `RunData`, creates runtime `DungeonNodeData`, applies explicit descriptor connections, and instantiates `DungeonNodeView` buttons.
5. Haven starts revealed, visited, occupied by Warrior's run-owned dungeon pawn, and marked by a visual pawn token on the map. Haven's connected neighbors start revealed, but Haven does not start resolved.
6. Clicking a reachable revealed node requests path-based travel for the selected pawn through `RunData.request_selected_dungeon_pawn_travel()`. If that pawn belongs to the active local leader, active `AutoPilot` party pawns receive matching same-destination follow orders when they can path there.
7. `DungeonController` runs a travel loop that asks `DungeonMovementCoordinator` to advance all active travel orders one node step, charges `RunData.NODE_STEP_DUNGEON_TIME_SECONDS` once per shared step, refreshes pawn markers, and waits `1 / RunData.VISUAL_NODE_STEPS_PER_REAL_SECOND` between steps.
8. Arrival processing marks each entered node visited, reveals descriptor-connected neighbors, emits `node_event_emitted(event)`, emits node-specific entry signals where available, and then processes node behavior.
9. Empty nodes resolve immediately on entry after the shared movement step has already charged `RunData.NODE_STEP_DUNGEON_TIME_SECONDS`.
10. Haven entry emits Haven node-entry signals but does not auto-resolve until a future Haven behavior defines that completion state.
11. Encounter nodes become visited before the encounter starts, lock the entering pawn as a participant, load their scene by descriptor `encounter_id`, wait for a supported `encounter_finished` completion result, then apply the selected choice effects to `RunData`, resolve the node, and unlock only pawns locked to that event node.
12. Entering an unresolved fight or boss marks the node visited, locks the entering pawn as a participant, and calls `GameManager.start_combat(node_id, node_type, enemy_profile_path, is_boss, false)` so the old direct-click travel charge is not applied on top of the movement step.
13. `GameManager` stores encounter metadata and routes to `combat/BattleScene`.
14. `battle_scene.gd` loads the encounter profile from `GameManager.get_current_encounter()`, applies effective Warrior `CombatantState` stats and persistent HP through the existing player bridge, runs combat, and creates a `CombatResult`.
15. `GameManager.complete_combat(result)` stores the result and routes back to `dungeon`.
16. `dungeon_controller.gd` consumes the pending result, updates `RunData`, resolves victorious fight/boss nodes, unlocks only pawns participating in that event node, emits HUD state, and either continues or routes to `run_summary`.
17. `run_summary.gd` shows totals and returns to `waiting_room`.

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
- `RunData.dungeon_map_pawns` owns active dungeon pawn state. Phase 2 creates one Warrior pawn and links `PlayerPartyMemberState.map_pawn_id`.
- `DungeonMap.tscn` has a `PawnLayer` above `NodeLayer`; `DungeonMapPawnView` instances display pawn state but do not own movement or gameplay position.
- Warrior's `CombatantState` is the intended persistent run model for player stats and HP.
- `RunData.player_current_hp`, `player_max_hp`, and `player_base_stats` are compatibility mirrors synchronized with Warrior's `CombatantState` for existing HUD, encounter, and combat call sites.
- `RunData.run_stat_modifiers` stores permanent and run-time-limited stat buffs and is mirrored into Warrior's `CombatantState`. `GameManager.advance_run_time()` ticks temporary modifiers.
- `RunData.pending_combat_result` is a handoff between `BattleScene` and `DungeonController`.
- `RunData.revealed_dungeon_node_ids`, `visited_dungeon_node_ids`, and `resolved_dungeon_node_ids` are the run-owned dungeon node state collections. `visited` means a pawn has entered a node; `resolved` means that node's current event or effect is complete.
- `RunData.current_dungeon_node_id` remains a compatibility mirror of Warrior's selected dungeon pawn position. Pawn-specific visits by other future pawns should not move this selected-pawn mirror.
- `RunData.request_selected_dungeon_pawn_travel()` creates a path-based travel order for the selected pawn or queues a pending destination replacement while the pawn is already traveling. Accepted local-leader orders also ask active `AutoPilot` pawns to follow the same destination if reachable.
- `DungeonMovementCoordinator` advances active pawn travel orders together. If one pawn reaches a destination, event node, cancellation point, or invalid replacement path, movement pauses after that shared step.
- `AutoPilot` follow behavior is intentionally minimal: followers use their own path from their current node, queue destination replacements with the leader when possible, and otherwise remain idle/waiting. No scouting or independent decision-making exists yet.
- Unresolved Fight, Boss, and Encounter arrivals lock only the entering pawn with `active_event_node_id`; adjacent or other idle pawns are not participants.
- `RunData.complete_dungeon_node()` resolves the node globally but prefers explicit pawn IDs or pawns currently locked to that event node for position synchronization and unlocking. It falls back to the selected pawn only when no event participant lock exists.
- Unsupported/non-complete encounter result modes are treated as authoring errors: the encounter scene stays active, the node remains unresolved, and event-locked pawns remain locked until a supported completion result is emitted.
- Generated descriptors may include `connections`; when omitted, the dungeon controller falls back to old id-order linear connections.
- The global HUD listens to `GameManager.run_time_changed` and `GameManager.run_currencies_changed`.

## See also

- [[Autoload APIs]]
- [[Scene routes]]
- [[Signals and events]]
- [[Adding a scene route]]
