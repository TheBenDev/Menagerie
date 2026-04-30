---
title: Data and resource model
page-type: guide
status: draft
---

Gameplay data is authored as Godot `.tres` resources that point to resource scripts under `res://scripts/data`.

## Resource categories

| Category | Resource script | Current authored data |
| --- | --- | --- |
| Character profile | `CombatantProfile` | `res://data/characters/Warrior/warrior_profile.tres` |
| Moveset | `CombatMovesetData` | `res://data/characters/Warrior/warrior_moveset.tres` |
| Enemy profile | `CombatantProfile` | `res://data/enemies/Training_Ghoul/training_ghoul_profile.tres` |
| Enemy AI profile | `EnemyAIProfile` | `res://data/enemies/Training_Ghoul/training_ghoul_ai.tres` |
| Difficulty | `DifficultyProfile` | `easy.tres`, `normal.tres`, `hard.tres` |
| Status | `StatusData` | `weaken.tres`, `vulnerable.tres` |
| Reward | `RewardProfile` | `training_ghoul_rewards.tres` |
| UI resource bar | `ResourceBarConfig` | Embedded in combatant profiles. |
| Audio library | `AudioLibraryData` | `res://data/audio/common_audio_library.tres` |
| Visual state machine | Easy State Machine `SMConfig` | Warrior and Training Ghoul visual configs. |

## Character and enemy data flow

1. A `CombatantProfile` stores display data, stats, moveset, audio IDs, reward/AI references, and resource bar configs.
2. `Combatant.apply_profile()` copies stats and actions from the profile into runtime fields.
3. A player combatant reads `profile.moveset.actions`.
4. An enemy combatant reads `profile.enemy_ai_profile.moves`.
5. The HUD reads `profile.health_bar` and `profile.resource_bars` through `Combatant.get_*_config()`.
6. `CombatAudioBridge` reads profile SFX IDs for hit, block, and death events.

## Action data flow

1. `CombatActionData` defines ID, display name, time cost, costs, target side, SFX IDs, and effects.
2. `PlayerActionData` adds player-only fields such as rage cost and tooltip text.
3. `EnemyMoveData` adds AI metadata such as weights, HP gates, target rules, roles, and status preferences.
4. Each action owns an ordered `effects` array.
5. Effects are `ActionEffect` resources with a namespaced `effect_id`.
6. `CombatEffectLibrary` maps the ID to runtime behavior.

## Status data flow

Statuses live under `res://data/statuses`.

`CombatEffectLibrary.status_path_for_id()` accepts:

- `status.weaken` -> `res://data/statuses/weaken.tres`
- `weaken` -> `res://data/statuses/weaken.tres`
- `res://data/statuses/weaken.tres` -> exact path

## Godot resource practices

- Use Godot or the Godot AI MCP tools for scene/resource edits when possible.
- Do not manually create or edit `.uid` files.
- Prefer plain `path="res://..."` references when adding a new script or resource by hand.
- Use `;` comments in `.tres` and `.tscn` files.
- Keep subresources near the action or move that uses them.

## See also

- [[Resource inventory]]
- [[Adding a combat action]]
- [[Adding an enemy]]
- [[Adding a status or effect]]
- [[Adding a difficulty]]
