---
title: Battle visuals
page-type: guide
status: draft
---

Battle visuals are reusable `Control` scenes with an `AnimatedSprite2D` and Easy State Machine states.

## Current visual scenes

| Scene | Purpose |
| --- | --- |
| `res://scenes/combatants/characters/warrior/WarriorBattleVisual.tscn` | Player warrior battle visual. |
| `res://scenes/combatants/enemies/training_ghoul/TrainingGhoulBattleVisual.tscn` | Training Ghoul battle visual. |

## Runtime scripts

| Script | Role |
| --- | --- |
| `res://scenes/combatants/combatant_battle_visual.gd` | `CombatantBattleVisual`; fits an `AnimatedSprite2D` inside its control bounds. |
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

## See also

- [[Adding a battle visual]]
- [[Asset inventory]]
- [[Script inventory]]
