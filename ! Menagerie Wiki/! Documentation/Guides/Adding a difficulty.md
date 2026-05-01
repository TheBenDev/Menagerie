---
title: Adding a difficulty
page-type: guide
status: draft
---

Use this guide to add a new difficulty profile and expose it to run setup.

## Create the profile

1. Create a `DifficultyProfile` resource under `res://core/difficulty`.
2. Set:
   - `id`
   - `display_name`
   - enemy multipliers
   - reward multiplier
   - AI tuning weights
3. Use `res://core/difficulty/normal.tres` as the baseline.

## Register the profile

1. Update `GameManager.DIFFICULTY_PROFILE_PATHS` in `res://core/game_manager.gd`.
2. If this difficulty should be selectable in the waiting room, update `res://scenes/ui/waiting_room/waiting_room.tscn` and `res://scenes/ui/waiting_room/waiting_room.gd`.
3. Keep `RunData.DEFAULT_DIFFICULTY` unchanged unless the project default should move.

## Runtime effects

`BattleController._apply_difficulty_profile()` applies:

- `enemy_health_multiplier`
- `enemy_damage_multiplier`
- `enemy_time_cost_multiplier`

`GameManager.calculate_rewards_for_profile()` applies:

- `reward_multiplier`

`EnemyBrain` reads AI tuning values:

- `ai_randomness`
- `ai_score_strength`
- `ai_survival_awareness`
- `ai_finisher_priority`
- `ai_debuff_awareness`
- `ai_timing_awareness`

## Validate behavior

- Start a run with the new difficulty.
- Confirm `GlobalHUD` and dungeon header show the display name.
- Confirm enemy HP/damage/time and rewards use the new values.
- Confirm invalid/missing profile paths do not appear in Godot load warnings.
- Run the headless load command after script/resource changes.

## See also

- [[Resource inventory]]
- [[Run flow]]
- [[Combat flow]]
- [[Autoload APIs]]
