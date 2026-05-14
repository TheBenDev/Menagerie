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
2. `Combatant.apply_profile()` copies stats and actions from the profile into runtime fields.
3. A player combatant reads `profile.moveset.actions`.
4. An enemy combatant reads `profile.enemy_ai_profile.moves`.
5. `BattleScene` owns combatant display nodes. Each `CombatantDisplay` reads `profile.battle_visual_scene` and `profile.health_bar`, while `BattleHUD` reads the player's `profile.resource_bars` for the hotbar resource bar.
6. `CombatAudioBridge` reads profile SFX IDs for hit, block, and death events.

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
