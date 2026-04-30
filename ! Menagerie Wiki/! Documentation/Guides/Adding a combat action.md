---
title: Adding a combat action
page-type: guide
status: draft
---

Use this guide to add a player action or enemy move backed by `CombatActionData` resources.

## Prerequisites

- Know whether the action belongs to a player moveset or an enemy AI profile.
- Choose existing effect IDs when possible: `combat.damage`, `combat.block`, `status.apply`, `resource.rage.gain`, or `stat.strength.add`.
- Identify start/resolve SFX IDs if the action needs audio.

## Add a player action

1. Open `res://data/characters/Warrior/warrior_moveset.tres` in Godot.
2. Add any needed `ActionEffect` subresources directly before the action that uses them.
3. Add a `PlayerActionData` subresource.
4. Set the action fields:
   - `id`: stable lower_snake_case action ID.
   - `display_name`: UI label.
   - `time_cost`: base duration in seconds.
   - `target_enemy`: true for attacks, false for self-targeting actions.
   - `effects`: ordered effect resources.
   - `start_sfx_id` and `resolve_sfx_id` if needed.
5. Add the action to the moveset `actions` array.
6. Keep related subresources grouped together.

## Add an enemy move

1. Open the enemy AI profile, such as `res://data/enemies/Training_Ghoul/training_ghoul_ai.tres`.
2. Add `ActionEffect` subresources directly before the move that uses them.
3. Add an `EnemyMoveData` subresource.
4. Set base action fields from `CombatActionData`.
5. Set enemy-only fields:
   - `weight`: authored random/scored weight.
   - `target_rule`: `RandomOpponent` or `Self`.
   - `min_hp_percent` and `max_hp_percent`: HP gate for valid move selection.
   - `ai_role`: damage, debuff, defense, finisher, etc.
   - `status_id`: useful for debuff scoring.
6. Add the move to the AI profile `moves` array.

## Validate behavior

- Confirm the action appears on the battle action bar if it is a player action.
- Confirm the enemy can choose the move when HP gates and targets are valid.
- Confirm timeline duration matches `time_cost` after difficulty/action multipliers.
- Confirm SFX IDs exist in [[Audio IDs]] if used.
- Run a headless load after resource/script changes:

```powershell
& 'H:\Apps\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

## See also

- [[Combat flow]]
- [[Data and resource model]]
- [[Resource inventory]]
- [[Key runtime APIs]]
- [[Adding a status or effect]]
