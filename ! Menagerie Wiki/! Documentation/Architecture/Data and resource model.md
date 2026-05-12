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
| UI resource bar | `ResourceBarConfig` | Embedded in combatant profiles. |
| Audio library | `AudioLibraryData` | `res://assets/audio/common_audio_library.tres` |
| Visual state machine | Easy State Machine `SMConfig` | Warrior and Training Ghoul visual configs. |

## Character and enemy data flow

1. A `CombatantProfile` stores display data, battle visual scene, stats, moveset, audio IDs, reward/AI references, and resource bar configs.
2. `Combatant.apply_profile()` copies stats and actions from the profile into runtime fields.
3. A player combatant reads `profile.moveset.actions`.
4. An enemy combatant reads `profile.enemy_ai_profile.moves`.
5. `BattleScene` owns combatant display nodes, and each `CombatantDisplay` reads `profile.battle_visual_scene`, `profile.health_bar`, and `profile.resource_bars` through `Combatant` accessors.
6. `CombatAudioBridge` reads profile SFX IDs for hit, block, and death events.

## Action data flow

1. `CombatActionData` defines ID, display name, time cost, costs, target side, SFX IDs, and `effect_data`.
2. `PlayerActionData` adds player-only fields such as rage cost and tooltip text.
3. `EnemyMoveData` adds AI metadata such as weights, HP gates, target rules, roles, and status preferences.
4. Each action owns an ordered `effect_data` array of dictionaries.
5. Each effect dictionary uses `id` for the namespaced effect behavior and adds the fields needed by that behavior.
6. `CombatEffectLibrary` maps the ID to runtime behavior.

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
