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
| Combat encounter profile | `DungeonCombatEncounterData` | `res://core/dungeon/encounters/combat/training_ghoul_fight.tres` |
| Combat encounter pool | `DungeonCombatEncounterPool` | `res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres` |
| Difficulty | `DifficultyProfile` | `res://core/difficulty/easy.tres`, `res://core/difficulty/normal.tres`, `res://core/difficulty/hard.tres` |
| Status | `StatusData` | `res://core/statuses/weaken.tres`, `res://core/statuses/vulnerable.tres` |
| Reward | `RewardProfile` | `res://core/rewards/training_ghoul_rewards.tres` |
| Dungeon ability pool | `DungeonAbilityPool` | `res://core/dungeon/abilities/default_dungeon_ability_pool.tres` |
| Dungeon ability | `DungeonAbilityData` | Embedded in `default_dungeon_ability_pool.tres`. |
| UI resource bar | `ResourceBarConfig` | Embedded in combatant profiles. |
| Audio library | `AudioLibraryData` | `res://assets/audio/common_audio_library.tres` |
| Visual state machine | Easy State Machine `SMConfig` | Warrior and Training Ghoul visual configs. |

## Character and enemy data flow

1. A `CombatantProfile` stores display data, battle visual scene, base stats, stat weights, moveset, audio IDs, reward/AI references, and resource bar configs.
2. `RunData.initialize_player_state()` creates a `PlayerPartyState` with one active Warrior `PlayerPartyMemberState`.
3. Warrior's `PlayerPartyMemberState` references a reusable `CombatantState` built from `warrior_profile.tres`.
4. `RunData.initialize_dungeon_map_state()` creates Warrior's `DungeonMapPawnState`, links it through `PlayerPartyMemberState.map_pawn_id`, and seeds Haven/neighbor node state from generated descriptors.
5. `DungeonController` creates `DungeonMapPawnView` markers on `DungeonMap.tscn`'s `PawnLayer` from the active pawn state; marker views are display-only.
6. `BattleScene` instantiates player and enemy combatant nodes under its runtime `Combatants` root, instantiates temporary combat-only copies for extra allies/enemies, and calls `Combatant.apply_profile()` to copy identity/actions before runtime stat changes.
7. Before battle, `GameManager.apply_run_player_state_to_combatant()` copies effective Warrior `CombatantState` stats onto the node-based player combatant bridge.
8. Generated Fight/Boss descriptors store `combat_encounter_id`, `combat_encounter_profile_path`, legacy `enemy` profile path data, and generated `enemy_instances` with profile path, slot position, enemy level, and stat seed.
9. `BattleScene` consumes `enemy_instances` to create enemy combatants, rolls fallback instances from `DungeonCombatEncounterData` only when old descriptors do not contain generated payloads, and applies level-scaled stats through `CombatantStatAllocator`.
10. Enemy `position_id` values select authored `EnemySlots/*` markers in `BattleScene.tscn`; the current player display is placed at `PlayerSlot1`, while temporary AI player copies use `PlayerSlot2/3`.
11. `BattleScene` wraps current player/enemy arrays in `CombatantGroup` instances before starting `BattleController`.
12. A player combatant reads `profile.moveset.actions`.
13. Enemy combatants read `profile.enemy_ai_profile.moves`; AI-controlled player copies use their normal `profile.moveset.actions`.
14. `BattleScene` owns combatant display nodes. Each `CombatantDisplay` reads `profile.battle_visual_scene` and `profile.health_bar`, while `BattleHUD` reads the player's `profile.resource_bars` for the hotbar resource bar.
15. `CombatAudioBridge` reads profile SFX IDs for hit, block, and death events across configured combatant groups.

## Runtime state objects

| Runtime state | Source | Purpose |
| --- | --- | --- |
| `CombatantState` | `res://core/combat/combatant_state.gd` | Reusable persistent combat state for anything that can participate in combat. |
| `CombatantGroup` | `res://core/combat/combatant_group.gd` | Temporary combat-side collection for player or enemy combatants during one battle. |
| `PartyControlMode` | `res://core/party/party_control_mode.gd` | Shared enum and helpers for `LocalPlayer`, `AutoPilot`, `RemotePlayer`, and `Inactive`. |
| `PlayerPartyMemberState` | `res://core/party/player_party_member_state.gd` | Player-party wrapper around a `CombatantState`, including control mode and future pawn ID. |
| `PlayerPartyState` | `res://core/party/player_party_state.gd` | Player-owned roster, active member IDs, leader, and selected member. |
| `DungeonMapPawnState` | `res://core/dungeon/dungeon_map_pawn_state.gd` | Run-owned dungeon position, control mode, travel orders, and event-lock state for one active party member. |
| `DungeonPathfinder` | `res://core/dungeon/dungeon_pathfinder.gd` | Reusable route helper for allowed paths through dungeon descriptor connection graphs. |
| `DungeonMovementCoordinator` | `res://core/dungeon/dungeon_movement_coordinator.gd` | Reusable synchronized node-step coordinator for active dungeon pawn travel orders. |
| `StatId` | `res://core/combat/stat_id.gd` | Shared stat IDs and profile field mapping for `STR`, `DEX`, `INT`, and `VIT`. |

`CombatantState` owns persistent player HP and stats. `CombatResult.participant_results` carries combatant IDs, side IDs, and HP snapshots across the combat-scene handoff so `RunData` can apply player-side participant results back to matching `CombatantState` objects. `RunData.current_dungeon_node_id` remains synchronized while the selected `DungeonMapPawnState` is the intended source of map position. `visited_dungeon_node_ids` and `resolved_dungeon_node_ids` are separate: visited means a pawn entered the node, while resolved means the node's event/effect is complete; resolved nodes are also visited and revealed. Path-based travel orders live on `DungeonMapPawnState`, `DungeonMovementCoordinator` advances them in synchronized node steps, and arrival handling processes all moved pawns before starting the one routed event supported by the current single-local-player scene flow. Future multiplayer should replace that single route handoff with combat/event instances using a shared clock.

## Action data flow

1. `CombatActionData` defines ID, display name, time cost, costs, `target_rule`, legacy target side, SFX IDs, and `effect_data`.
2. `PlayerActionData` adds player-only fields such as rage cost and tooltip text.
3. `EnemyMoveData` adds AI metadata such as weights, HP gates, roles, and status preferences.
4. Each action owns an ordered `effect_data` array of dictionaries.
5. Each effect dictionary uses `id` for the namespaced effect behavior and adds the fields needed by that behavior.
6. `CombatTargeting` resolves `SingleEnemy`, `SingleAlly`, `RandomEnemy`, `Self`, `AllAllies`, and `AllEnemies` target modes for local input and AI.
7. `CombatEffectLibrary` maps the ID to runtime behavior.

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
