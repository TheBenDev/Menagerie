---
title: Battle visuals
page-type: guide
status: draft
---

Battle visuals are reusable `Control` scenes with an `AnimatedSprite2D` and Easy State Machine states.

`res://scenes/combat/BattleScene.tscn` is the combat scene root. Add any future visual-stage layout directly in that scene rather than through a separate child scene.

## Combat slot markers

`BattleScene.tscn` owns invisible authored `Control` markers for combatant display placement:

- `PlayerSlots/PlayerSlot1`
- `PlayerSlots/PlayerSlot2`
- `PlayerSlots/PlayerSlot3`
- `EnemySlots/EnemySlot1`
- `EnemySlots/EnemySlot2`
- `EnemySlots/EnemySlot3`
- `EnemySlots/EnemySlot4`

`PlayerSlot1` and `EnemySlot1` are the primary combatant display positions. `BattleScene` instantiates `CombatantDisplay.tscn` for every player and enemy combatant. Player-side copies use `PlayerSlot2/3`; enemies use generated `enemy_instances[].position_id` with `EnemySlot*` fallbacks.

## Current visual scenes

| Scene | Purpose |
| --- | --- |
| `res://scenes/combatants/characters/warrior/WarriorBattleVisual.tscn` | Player warrior battle visual. |
| `res://scenes/combatants/enemies/training_ghoul/TrainingGhoulBattleVisual.tscn` | Training Ghoul battle visual. |

## Runtime scripts

| Script | Role |
| --- | --- |
| `res://scenes/combatants/combatant_battle_visual.gd` | `CombatantBattleVisual`; fits an `AnimatedSprite2D` inside its control bounds and reports fitted sprite bounds to combat UI. |
| `res://scenes/combatants/combatant_animation_state_helper.gd` | Shared helper used by animation state scripts to play or pin `AnimatedSprite2D` animations. |
| `res://scenes/combatants/characters/warrior/states/warrior_idle_state.gd` | Easy State Machine state that plays an `idle` animation. |
| `res://scenes/combatants/combatant_static_state.gd` | Easy State Machine state that displays a single `static` frame. |

## Data resources

| Resource | Role |
| --- | --- |
| `res://scenes/combatants/characters/warrior/warrior_visual_state_machine_config.tres` | Easy State Machine config for the warrior visual. |
| `res://scenes/combatants/enemies/training_ghoul/training_ghoul_visual_state_machine_config.tres` | Easy State Machine config for the Training Ghoul visual. |

## Scene pattern

Each visual scene should contain:

- A root `Control` with `CombatantBattleVisual`.
- An `AnimatedSprite2D` child.
- A `StateMachine` child using the Easy State Machine runtime script.
- One or more state nodes, usually `IdleState` or `StaticState`.
- A SpriteFrames resource in the combatant's `textures` folder.

`CombatantDisplay` places the combatant name in a hover-only contrast panel below the HP row. Class-specific resource bars are shown by the combat hotbar, not by the combatant visual.

During explicit player targeting, `CombatantDisplay` creates a runtime `TargetHighlight` overlay and emits `target_selected(combatant)` when a highlighted display is left-clicked. The overlay is not authored in `CombatantDisplay.tscn`; it is created by the display script so later instantiated displays inherit the same target behavior.

## See also

- [[Adding a battle visual]]
- [[Asset inventory]]
- [[Script inventory]]
