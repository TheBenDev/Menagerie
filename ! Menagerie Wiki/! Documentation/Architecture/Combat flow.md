---
title: Combat flow
page-type: guide
status: draft
---

Combat is a time-based queue where the player chooses actions, the enemy AI chooses moves, and due actions resolve on snapped time ticks.

## Main actors

| Actor                 | Source                                                  | Responsibility                                                                                  |
| --------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `BattleScene`         | `res://scenes/combat/battle_scene.gd`           | Scene coordinator for combatants, HUD, audio bridge, run data, and final result reporting.      |
| `BattleController`    | `res://core/combat/battle/battle_controller.gd`      | Advances combat time, queues actions, resolves simultaneous actions, and requests player input. |
| `Combatant`           | `res://scenes/combatants/combatant.gd`          | Holds stats, HP, block, statuses, available actions, and pending action state.                  |
| `WarriorCombatant`    | `res://scenes/combatants/characters/warrior/warrior_combatant.gd`  | Adds rage gain/decay and rage snapshots for the HUD.                                            |
| `EnemyBrain`          | `res://core/combat/ai/enemy_brain.gd`                | Chooses enemy moves from authored weights and difficulty-aware scoring.                         |
| `ActionResolver`      | `res://core/combat/actions/action_resolver.gd`       | Applies action costs and calls each action effect.                                              |
| `CombatEffectLibrary` | `res://core/combat/actions/combat_effect_library.gd` | Resolves namespaced effect IDs such as `combat.damage` and `status.apply`.                      |

## Runtime sequence

1. `BattleScene._ready()` configures the encounter from `GameManager`, applies profiles, wires signals, and calls `battle.start_battle()`.
2. `BattleController.start_battle()` resets combatants, applies difficulty modifiers, emits `action_queue_changed`, logs battle start, and emits `player_ready`.
3. `BattleHUD` enables action buttons while `battle.waiting_for_player_input` is true.
4. Selecting an action calls `BattleController.player_choose_action(action)`.
5. The player starts the action, a `QueuedAction` is appended, and enemy AI chooses an action if idle.
6. `BattleController.advance_until_input_needed()` advances by `CombatTime.TIME_STEP_SECONDS`.
7. Each tick emits `time_changed`, ticks statuses/resources, resolves due actions, and asks the enemy to act if needed.
8. Due queue entries are ordered by resolve time, then highest dexterity, then rerolled d6 ties.
9. `Combatant.resolve_pending_action()` calls `ActionResolver.resolve_action()`.
10. `ActionResolver` applies HP costs, then calls each `ActionEffect.apply()`.
11. Damage/status/block/rage behavior is dispatched through `CombatEffectLibrary`.
12. Death signals mark the battle over and `BattleScene` creates a `CombatResult`.

## Effect IDs

| ID | Behavior |
| --- | --- |
| `combat.damage` | Deals stat-scaled damage, applies outgoing and incoming multipliers, then block and HP loss. |
| `combat.block` | Grants block to the source combatant. |
| `status.apply` | Loads a status resource from `res://core/statuses` and applies it to targets. |
| `resource.rage.gain` | Calls `gain_rage()` on sources that implement it. |
| `stat.strength.add` | Adds strength to targets, or to the source if no targets are supplied. |

## Timing rules

- Time is snapped with `CombatTime.TIME_STEP_SECONDS`, currently `0.1`.
- Action duration is `action.time_cost * actor.action_time_multiplier`, then snapped.
- The run timer advances by combat elapsed time through `BattleScene._on_battle_time_changed()`.
- Time scale changes how long ticks wait in real time; it does not change in-game action duration.

## See also

- [[Key runtime APIs]]
- [[Signals and events]]
- [[Adding a combat action]]
- [[Adding a status or effect]]
