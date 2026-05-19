# Combat Manager Migration

## Target

`CombatManager` owns combat session setup, payload validation, current combat context, and completion handoff.

## Migration Notes

- `BattleScene` should consume a validated payload and render/run the battle.
- Combat completion should flow through `BattleScene -> CombatManager -> DungeonManager -> GameManager`.
- Runtime enemy instances use `instance_id`, `profile_path`, `slot_id`, `level`, and `stat_seed`.

## Documentation Follow-Up

- Update combat flow, payload, result, and reward docs after migration settles.
