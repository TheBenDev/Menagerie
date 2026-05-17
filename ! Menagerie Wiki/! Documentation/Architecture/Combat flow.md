---
title: Combat flow
page-type: guide
status: draft
---

Combat is a time-based queue where the local leader chooses actions, AI-controlled allies/enemies choose moves, and due actions resolve on snapped time ticks.

## Main actors

| Actor                 | Source                                                  | Responsibility                                                                                  |
| --------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `BattleScene`         | `res://scenes/combat/battle_scene.gd`           | Scene coordinator for combatants, HUD, audio bridge, run data, and final result reporting.      |
| `BattleController`    | `res://core/combat/battle/battle_controller.gd`      | Advances combat time, queues actions, resolves simultaneous actions, and requests player input. |
| `CombatantGroup`      | `res://core/combat/combatant_group.gd`          | Temporary player-side or enemy-side combatant collection with living/dead helper methods.       |
| `Combatant`           | `res://scenes/combatants/combatant.gd`          | Holds stats, HP, block, statuses, available actions, and pending action state.                  |
| `WarriorCombatant`    | `res://scenes/combatants/characters/warrior/warrior_combatant.gd`  | Adds rage gain/decay and rage snapshots for the HUD.                                            |
| `CombatBrain`         | `res://core/combat/ai/combat_brain.gd`               | Chooses AI actions and targets for either side using authored weights and difficulty scoring.   |
| `CombatTargeting`     | `res://core/combat/actions/combat_targeting.gd`      | Resolves action target modes for local input and AI-controlled combatants.                      |
| `ActionResolver`      | `res://core/combat/actions/action_resolver.gd`       | Applies action costs and sends each effect data dictionary to the effect library.                |
| `CombatEffectLibrary` | `res://core/combat/actions/combat_effect_library.gd` | Resolves namespaced effect data IDs such as `combat.damage` and `status.apply`.                 |

## Runtime sequence

1. `BattleScene._ready()` configures the encounter from `GameManager`, consumes generated `enemy_instances`, instantiates the local player combatant plus combat-only AI player copies, creates enemy combatants, positions displays from authored slot markers, configures combatant groups, wires signals, and calls `battle.start_battle()`.
2. `BattleController.start_battle()` ensures `player_group` and `enemy_group`, resets group combatants, applies difficulty modifiers, emits `action_queue_changed`, logs battle start, and emits `player_ready`.
3. `BattleHUD` enables action buttons while `battle.waiting_for_player_input` is true and no target confirmation is active.
4. Selecting a manual single-target action starts `BattleScene` targeting state; selecting a `Self`, `AllAllies`, or `AllEnemies` action queues it immediately.
5. For manual actions, `BattleScene` resolves living valid targets from the action side, highlights matching `CombatantDisplay` nodes, and waits for click or accept-key confirmation.
6. Confirming a target calls `BattleController.player_choose_action(action, explicit_targets)` with the selected target array. Auto-targeted actions call `player_choose_action(action)` without explicit targets.
7. The player starts the action, a `QueuedAction` is appended, and living idle AI-controlled allies/enemies choose actions.
8. `BattleController.advance_until_input_needed()` advances by `CombatTime.TIME_STEP_SECONDS`.
9. Each tick emits `time_changed`, ticks statuses/resources for group combatants, resolves due actions, and asks idle living AI combatants to act if needed.
10. Due queue entries are ordered by resolve time, then highest dexterity, then rerolled d6 ties.
11. `Combatant.resolve_pending_action()` calls `ActionResolver.resolve_action()`.
12. `ActionResolver` applies HP costs, then dispatches each `effect_data` dictionary.
13. Damage/status/block/rage behavior is dispatched through `CombatEffectLibrary`.
14. Death signals update group state. Combat ends only when the player group or enemy group has no living combatants, then `BattleScene` creates a `CombatResult`.

## Player targeting

Manual single-target actions use explicit targeting even when only one target is valid. Player action hotkeys or hotbar clicks store a pending action on `BattleScene`, disable further action-button selection through `BattleHUD.set_targeting_active()`, and highlight valid `CombatantDisplay` nodes. Left-clicking a highlighted display confirms that combatant. `ui_accept`, Enter, or Space also confirms when exactly one valid target exists. `ui_cancel`, Escape, Backspace, or right-click cancels targeting and returns to action selection.

Actions authored with `target_rule` values `Self`, `AllAllies`, or `AllEnemies` do not enter explicit targeting. They resolve targets through `CombatTargeting` when queued.

## Combat placement

`BattleScene.tscn` contains authored invisible slot markers under `PlayerSlots` and `EnemySlots`. Runtime instantiates `CombatantDisplay.tscn` for every player and enemy combatant. The local player uses `PlayerSlot1`, combat-only AI player copies use `PlayerSlot2/3`, and generated enemy instances use their `position_id` with `EnemySlot*` fallbacks.

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
