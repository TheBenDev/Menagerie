---
title: Resource inventory
page-type: reference
status: draft
---

This inventory lists authored gameplay/audio `.tres` files under `res://data`, excluding `.uid` files.

## Totals

| Group | Count |
| --- | ---: |
| `data/audio` | 1 |
| `data/characters` | 3 |
| `data/difficulty` | 3 |
| `data/enemies` | 3 |
| `data/rewards` | 1 |
| `data/statuses` | 2 |
| Total | 13 |

## Resources

| Resource | Script class | Purpose |
| --- | --- | --- |
| `res://data/audio/common_audio_library.tres` | `AudioLibraryData` | Authored music tracks and cue overrides. |
| `res://data/characters/Warrior/warrior_moveset.tres` | `CombatMovesetData` | Warrior player actions and embedded action effects. |
| `res://data/characters/Warrior/warrior_profile.tres` | `CombatantProfile` | Warrior stats, moveset, UI bars, and identity data. |
| `res://data/characters/Warrior/warrior_visual_state_machine_config.tres` | `SMConfig` | Easy State Machine config for warrior battle visual. |
| `res://data/difficulty/easy.tres` | `DifficultyProfile` | Easy difficulty tuning. |
| `res://data/difficulty/normal.tres` | `DifficultyProfile` | Normal difficulty tuning and default difficulty. |
| `res://data/difficulty/hard.tres` | `DifficultyProfile` | Hard difficulty tuning. |
| `res://data/enemies/Training_Ghoul/training_ghoul_ai.tres` | `EnemyAIProfile` | Training Ghoul move list and embedded enemy effects. |
| `res://data/enemies/Training_Ghoul/training_ghoul_profile.tres` | `CombatantProfile` | Training Ghoul stats, AI profile, rewards, UI bars, and identity data. |
| `res://data/enemies/Training_Ghoul/training_ghoul_visual_state_machine_config.tres` | `SMConfig` | Easy State Machine config for Training Ghoul visual. |
| `res://data/rewards/training_ghoul_rewards.tres` | `RewardProfile` | Base Training Ghoul memory/gold rewards and boss multiplier. |
| `res://data/statuses/vulnerable.tres` | `StatusData` | Timed incoming damage multiplier status. |
| `res://data/statuses/weaken.tres` | `StatusData` | Timed outgoing damage multiplier status. |

## Resource schemas

| Script class | Exported data |
| --- | --- |
| `CombatantProfile` | `display_name`, `placeholder_color`, `timeline_initial`, `timeline_color`, `strength`, `dexterity`, `intelligence`, `vitality`, `moveset`, `enemy_ai_profile`, `reward_profile`, `hit_sfx_id`, `block_sfx_id`, `death_sfx_id`, `health_bar`, `resource_bars`. |
| `CombatMovesetData` | `actions`. |
| `CombatActionData` | `id`, `display_name`, `time_cost`, `effects`, `start_sfx_id`, `resolve_sfx_id`, `hp_cost`, `mana_cost`, `target_enemy`. |
| `PlayerActionData` | Inherits `CombatActionData`; adds `rage_cost`, `required_stance`, `appears_on_action_bar`, `tooltip_text`. |
| `EnemyMoveData` | Inherits `CombatActionData`; adds `weight`, `target_rule`, `min_hp_percent`, `max_hp_percent`, `cooldown_seconds`, `ai_role`, `status_id`, preference/avoidance booleans. |
| `ActionEffect` | `effect_id`, `amount`, `base_damage`, `scaling_stat`, `scaling_multiplier`, `status_id`, `duration_override_seconds`. |
| `DifficultyProfile` | Enemy health/damage/time multipliers, reward multiplier, and AI tuning weights. |
| `StatusData` | `id`, `display_name`, `duration_seconds`, `outgoing_damage_multiplier`, `incoming_damage_multiplier`. |
| `RewardProfile` | `base_memories`, `base_gold`, `boss_multiplier`. |
| `ResourceBarConfig` | `resource_id`, `label`, `reference_value`, `display_reference_value`, colors, and `bonus_label`. |
| `AudioLibraryData` | `cues`, `music_tracks`. |
| `AudioCueData` | `id`, `stream_ids`, `streams`, `bus`, `volume_db`, `pitch_min`, `pitch_max`, `cooldown_seconds`, `max_instances`, `priority`. |
| `MusicTrackData` | `id`, `base_stream_id`, `base_stream`, playlist fields, `state_variants`, `bus`, `volume_db`, `default_fade_seconds`, `loop`. |
| `MusicStateData` | `state_id`, `stream_id`, `stream`, `fade_seconds`, `min_hold_seconds`. |

## See also

- [[Data and resource model]]
- [[Adding a combat action]]
- [[Adding an enemy]]
- [[Adding a difficulty]]
- [[Audio IDs]]
