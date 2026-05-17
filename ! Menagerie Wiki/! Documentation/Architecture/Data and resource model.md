---
title: Data and resource model
page-type: guide
status: draft
---

Gameplay data is authored as Godot `.tres` resources that point to resource scripts near their owning system. Shared combat data scripts live under `res://core`, while combatant-specific profiles, movesets, AI data, and visuals live with their combatant folders under `res://scenes/combatants`.

## Resource categories

| Category | Resource script | Current authored data |
| --- | --- | --- |
| Character profile | `CombatantProfile` | `res://scenes/combatants/characters/warrior/warrior_profile.tres` |
| Moveset | `CombatMovesetData` | `res://scenes/combatants/characters/warrior/warrior_moveset.tres` |
| Enemy profile | `CombatantProfile` | `res://scenes/combatants/enemies/training_ghoul/training_ghoul_profile.tres` |
| Enemy AI profile | `EnemyAIProfile` | `res://scenes/combatants/enemies/training_ghoul/training_ghoul_ai.tres` |
| Difficulty | `DifficultyProfile` | `res://core/difficulty/easy.tres`, `res://core/difficulty/normal.tres`, `res://core/difficulty/hard.tres` |
| Status | `StatusData` | `res://core/statuses/weaken.tres`, `res://core/statuses/vulnerable.tres` |
| Reward | `RewardProfile` | `res://core/rewards/training_ghoul_rewards.tres` |
| Dungeon ability pool | `DungeonAbilityPool` | `res://core/dungeon/abilities/default_dungeon_ability_pool.tres` |
| Dungeon ability | `DungeonAbilityData` | Embedded in `default_dungeon_ability_pool.tres`. |
| UI resource bar | `ResourceBarConfig` | Embedded in combatant profiles. |
| Audio library | `AudioLibraryData` | `res://assets/audio/common_audio_library.tres` |
| Visual state machine | Easy State Machine `SMConfig` | Warrior and Training Ghoul visual configs. |

## Character and enemy data flow

1. A `CombatantProfile` stores display data, battle visual scene, stats, moveset, audio IDs, reward/AI references, and resource bar configs.
2. `RunData.initialize_player_state()` creates a `PlayerPartyState` with one active Warrior `PlayerPartyMemberState`.
3. Warrior's `PlayerPartyMemberState` references a reusable `CombatantState` built from `warrior_profile.tres`.
4. `RunData.initialize_dungeon_map_state()` creates Warrior's `DungeonMapPawnState`, links it through `PlayerPartyMemberState.map_pawn_id`, and seeds Haven/neighbor node state from generated descriptors.
5. `DungeonController` creates `DungeonMapPawnView` markers on `DungeonMap.tscn`'s `PawnLayer` from the active pawn state; marker views are display-only.
6. Existing single-combatant battle scenes still instantiate `WarriorCombatant` and call `Combatant.apply_profile()` to copy stats and actions from the profile into node runtime fields.
7. Before battle, `GameManager.apply_run_player_state_to_combatant()` copies effective Warrior `CombatantState` stats onto the node-based combatant bridge.
8. A player combatant reads `profile.moveset.actions`.
9. An enemy combatant reads `profile.enemy_ai_profile.moves`.
10. `BattleScene` owns combatant display nodes. Each `CombatantDisplay` reads `profile.battle_visual_scene` and `profile.health_bar`, while `BattleHUD` reads the player's `profile.resource_bars` for the hotbar resource bar.
11. `CombatAudioBridge` reads profile SFX IDs for hit, block, and death events.

## Runtime state objects

| Runtime state | Source | Purpose |
| --- | --- | --- |
| `CombatantState` | `res://core/combat/combatant_state.gd` | Reusable persistent combat state for anything that can participate in combat. |
| `PartyControlMode` | `res://core/party/party_control_mode.gd` | Shared enum and helpers for `LocalPlayer`, `AutoPilot`, `RemotePlayer`, and `Inactive`. |
| `PlayerPartyMemberState` | `res://core/party/player_party_member_state.gd` | Player-party wrapper around a `CombatantState`, including control mode and future pawn ID. |
| `PlayerPartyState` | `res://core/party/player_party_state.gd` | Player-owned roster, active member IDs, leader, and selected member. |
| `DungeonMapPawnState` | `res://core/dungeon/dungeon_map_pawn_state.gd` | Run-owned dungeon position, control mode, travel orders, and event-lock state for one active party member. |
| `DungeonPathfinder` | `res://core/dungeon/dungeon_pathfinder.gd` | Reusable route helper for allowed paths through dungeon descriptor connection graphs. |
| `DungeonMovementCoordinator` | `res://core/dungeon/dungeon_movement_coordinator.gd` | Reusable synchronized node-step coordinator for active dungeon pawn travel orders. |

Phase 1 keeps legacy `RunData.player_current_hp`, `player_max_hp`, and `player_base_stats` as synchronized mirrors so existing dungeon HUD and combat code keep working while later phases migrate more systems to party and combatant state directly. Phase 2 similarly keeps `RunData.current_dungeon_node_id` synchronized while the selected `DungeonMapPawnState` becomes the intended source of map position. Phase 3 displays that pawn state through `DungeonMapPawnView` markers without moving gameplay authority into scene visuals. Phase 4 separates `visited_dungeon_node_ids` from `resolved_dungeon_node_ids`: visited means a pawn entered the node, while resolved means the node's event/effect is complete. Phase 5 adds `DungeonPathfinder` as a scene-independent route helper for later travel orders. Phase 6 stores path-based travel orders on `DungeonMapPawnState`; Phase 7 advances those orders in synchronized node steps; Phase 8 applies arrival effects by marking nodes visited, revealing neighbors, emitting entry signals, resolving Empty nodes, leaving Haven unresolved, and starting routed events from the arrived node. Phase 9 treats `DungeonMapPawnState.active_event_node_id` as the participant link for event completion so resolving a node unlocks only pawns that entered that event. Phase 10 uses `PartyControlMode.AutoPilot` as simple same-destination follow behavior when the local leader receives a valid travel order.

## Action data flow

1. `CombatActionData` defines ID, display name, time cost, costs, target side, SFX IDs, and `effect_data`.
2. `PlayerActionData` adds player-only fields such as rage cost and tooltip text.
3. `EnemyMoveData` adds AI metadata such as weights, HP gates, target rules, roles, and status preferences.
4. Each action owns an ordered `effect_data` array of dictionaries.
5. Each effect dictionary uses `id` for the namespaced effect behavior and adds the fields needed by that behavior.
6. `CombatEffectLibrary` maps the ID to runtime behavior.

## Dungeon map ability data flow

1. `DungeonAbilityData` defines class-agnostic hotbar metadata for map-only abilities.
2. `DungeonAbilityPool` stores the ordered default dungeon hotbar abilities.
3. `GameManager.get_dungeon_abilities()` returns abilities from `default_dungeon_ability_pool.tres`.
4. `DungeonController` renders the first three pool entries on the dungeon hotbar instead of reading character combat movesets.

## Status data flow

Statuses live under `res://core/statuses`.

`CombatEffectLibrary.status_path_for_id()` accepts:

- `status.weaken` -> `res://core/statuses/weaken.tres`
- `weaken` -> `res://core/statuses/weaken.tres`
- `res://core/statuses/weaken.tres` -> exact path

## Godot resource practices

- Use Godot or the Godot AI MCP tools for scene/resource edits when possible.
- Do not manually create or edit `.uid` files.
- Prefer plain `path="res://..."` references when adding a new script or resource by hand.
- Use `;` comments in `.tres` and `.tscn` files.
- Keep action and move subresources grouped with their inline `effect_data`.

## See also

- [[Resource inventory]]
- [[Adding a combat action]]
- [[Adding an enemy]]
- [[Adding a status or effect]]
- [[Adding a difficulty]]
