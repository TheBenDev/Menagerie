---
title: Resource inventory
page-type: reference
status: draft
---

This inventory lists authored gameplay, audio, UI, and visual `.tres` files under the current project layout, excluding `.uid` files.

## Totals

| Group | Count |
| --- | ---: |
| `assets/audio` | 1 |
| `assets/ui` | 1 |
| `core/dungeon` | 8 |
| `core/difficulty` | 3 |
| `core/rewards` | 1 |
| `core/statuses` | 2 |
| `scenes/combatants/characters` | 4 |
| `scenes/combatants/enemies` | 4 |
| Total | 24 |

## Resources

| Resource | Script class | Purpose |
| --- | --- | --- |
| `res://assets/audio/common_audio_library.tres` | `AudioLibraryData` | Authored music tracks and cue overrides. |
| `res://assets/ui/menagerie_theme.tres` | `Theme` | Project UI theme with Germania One defaults, compact combat text variations, Dumbledor title/header variations, and Gotfridus character-name variations. |
| `res://core/dungeon/abilities/default_dungeon_ability_pool.tres` | `DungeonAbilityPool` | Default class-agnostic dungeon hotbar abilities. |
| `res://core/dungeon/default_dungeon_floor_generation_config.tres` | `DungeonFloorGenerationConfig` | Default deterministic dungeon map generation tuning. |
| `res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres` | `DungeonCombatEncounterPool` | Scanned combat encounter registry for generated Fight/Boss nodes. |
| `res://core/dungeon/encounters/default_dungeon_encounter_pool.tres` | `DungeonEncounterPool` | Scanned dungeon encounter registry and default encounter scene. |
| `res://core/dungeon/encounters/combat/training_ghoul_fight.tres` | `DungeonCombatEncounterData` | Default seeded Fight/Boss combat encounter rolling one to three Training Ghoul enemy slots. |
| `res://core/dungeon/encounters/events/cracked_obelisk.tres` | `DungeonEncounterData` | Default Cracked Obelisk encounter. |
| `res://core/dungeon/encounters/events/forgotten_font.tres` | `DungeonEncounterData` | Default Forgotten Font encounter. |
| `res://core/dungeon/encounters/events/mysterious_shrine.tres` | `DungeonEncounterData` | Default Mysterious Shrine encounter. |
| `res://scenes/combatants/characters/warrior/textures/warrior_idle_frames.tres` | `SpriteFrames` | Warrior battle visual frames. |
| `res://scenes/combatants/characters/warrior/warrior_moveset.tres` | `CombatMovesetData` | Warrior player actions and inline effect data. |
| `res://scenes/combatants/characters/warrior/warrior_profile.tres` | `CombatantProfile` | Warrior stats, moveset, UI bars, and identity data. |
| `res://scenes/combatants/characters/warrior/warrior_visual_state_machine_config.tres` | `SMConfig` | Easy State Machine config for warrior battle visual. |
| `res://core/difficulty/easy.tres` | `DifficultyProfile` | Easy difficulty tuning. |
| `res://core/difficulty/normal.tres` | `DifficultyProfile` | Normal difficulty tuning and default difficulty. |
| `res://core/difficulty/hard.tres` | `DifficultyProfile` | Hard difficulty tuning. |
| `res://scenes/combatants/enemies/training_ghoul/textures/training_ghoul_visual_frames.tres` | `SpriteFrames` | Training Ghoul battle visual frames. |
| `res://scenes/combatants/enemies/training_ghoul/training_ghoul_ai.tres` | `EnemyAIProfile` | Training Ghoul move list and inline effect data. |
| `res://scenes/combatants/enemies/training_ghoul/training_ghoul_profile.tres` | `CombatantProfile` | Training Ghoul identity, stat weights, AI profile, rewards, and UI bars. |
| `res://scenes/combatants/enemies/training_ghoul/training_ghoul_visual_state_machine_config.tres` | `SMConfig` | Easy State Machine config for Training Ghoul visual. |
| `res://core/rewards/training_ghoul_rewards.tres` | `RewardProfile` | Base Training Ghoul memory/gold rewards and boss multiplier. |
| `res://core/statuses/vulnerable.tres` | `StatusData` | Timed incoming damage multiplier status. |
| `res://core/statuses/weaken.tres` | `StatusData` | Timed outgoing damage multiplier status. |

## Resource schemas

| Script class | Exported data |
| --- | --- |
| `CombatantProfile` | `display_name`, `placeholder_color`, `timeline_initial`, `timeline_color`, `battle_visual_scene`, `strength`, `dexterity`, `intelligence`, `vitality`, `stat_weights`, `moveset`, `enemy_ai_profile`, `reward_profile`, `hit_sfx_id`, `block_sfx_id`, `death_sfx_id`, `health_bar`, `resource_bars`. |
| `CombatMovesetData` | `actions`. |
| `CombatActionData` | `id`, `display_name`, `description`, `time_cost`, `effect_data`, `start_sfx_id`, `resolve_sfx_id`, `hp_cost`, `mana_cost`, `target_rule`, legacy `target_enemy`. |
| `PlayerActionData` | Inherits `CombatActionData`; adds `rage_cost`, `required_stance`, `appears_on_action_bar`, `tooltip_text`. |
| `EnemyMoveData` | Inherits `CombatActionData`; adds `weight`, `min_hp_percent`, `max_hp_percent`, `cooldown_seconds`, `ai_role`, `status_id`, preference/avoidance booleans. |
| `DifficultyProfile` | Enemy stat budgets, health/damage/time multipliers, reward multiplier, and AI tuning weights. |
| `StatusData` | `id`, `display_name`, `description`, `icon_atlas_coords`, `icon_atlas_cell_size`, `duration_seconds`, `outgoing_damage_multiplier`, `incoming_damage_multiplier`. |
| `RewardProfile` | `base_memories`, `base_gold`, `boss_multiplier`. |
| `DungeonAbilityPool` | `abilities`. |
| `DungeonAbilityData` | `id`, `display_name`, `hotbar_label`, `description`, `icon`, `enabled`. |
| `DungeonFloorGenerationConfig` | Grid size scaling, fight/encounter count scaling, enemy level ranges, branch/extra connection chances, path noise, room padding, placement attempts, and retry limits. |
| `DungeonCombatEncounterPool` | `scan_roots`. |
| `DungeonCombatEncounterData` | `id`, `display_name`, `description`, `valid_floor_layers`, `weight`, `min_enemy_count`, `max_enemy_count`, `enemy_slots`. Enemy slot dictionaries use `combatant_profile_path`, `position_id`, and optional `modifier_data`; `position_id` maps to an authored `EnemySlots/*` marker in `BattleScene.tscn`. |
| `DungeonEncounterPool` | `scan_roots`, `default_scene`. |
| `DungeonEncounterData` | `id`, `display_name`, `description`, `valid_floor_layers`, `weight`, `scene_override`, inline `choices`. |
| Dungeon encounter choice dictionaries | `label`, optional `description`, optional `effects`. |
| Dungeon encounter effect dictionaries | `id`, `amount`, and effect-specific keys such as `stat`, `duration`, `permanent`. |
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
