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

1. Open `res://scenes/combatants/characters/warrior/warrior_moveset.tres` in Godot.
2. Add a `PlayerActionData` subresource.
3. Add ordered `effect_data` dictionaries to the action.
4. Set the action fields:
   - `id`: stable lower_snake_case action ID.
   - `display_name`: UI label.
   - `description`: hover info panel description.
   - `time_cost`: base duration in seconds.
   - `target_rule`: `SingleEnemy` for manual target picking, `Self`, `AllAllies`, or `AllEnemies` for actions that queue without target picking, or `RandomEnemy` for random enemy targeting.
   - `effect_data`: ordered effect dictionaries such as `{"id": &"combat.damage", "base_damage": 4}`.
   - `start_sfx_id` and `resolve_sfx_id` if needed.
5. Add the action to the moveset `actions` array.
6. Keep related action subresources grouped together.

## Add an enemy move

1. Open the enemy AI profile, such as `res://scenes/combatants/enemies/training_ghoul/training_ghoul_ai.tres`.
2. Add an `EnemyMoveData` subresource.
3. Add ordered `effect_data` dictionaries to the move.
4. Set base action fields from `CombatActionData`.
5. Set enemy-only fields:
   - `weight`: authored random/scored weight.
   - `target_rule`: `SingleEnemy`, `RandomEnemy`, `Self`, `AllAllies`, or `AllEnemies`.
   - `min_hp_percent` and `max_hp_percent`: HP gate for valid move selection.
   - `ai_role`: damage, debuff, defense, finisher, etc.
   - `status_id`: useful for debuff scoring.
6. Add the move to the AI profile `moves` array.

## Validate behavior

- Confirm the action appears on the battle action bar if it is a player action.
- Confirm hovering the action shows the authored `description` in the battle info panel.
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
