---
title: Battle visuals
page-type: guide
status: draft
---

Battle visuals are reusable `Control` scenes with an `AnimatedSprite2D` and Easy State Machine states.

## Current visual scenes

| Scene | Purpose |
| --- | --- |
| `res://scenes/Battle/WarriorBattleVisual.tscn` | Player warrior battle visual. |
| `res://scenes/Battle/TrainingGhoulBattleVisual.tscn` | Training Ghoul battle visual. |

## Runtime scripts

| Script | Role |
| --- | --- |
| `res://scripts/ui/battle/warrior_battle_visual.gd` | `CombatantBattleVisual`; fits an `AnimatedSprite2D` inside its control bounds. |
| `res://scripts/ui/battle/warrior_idle_state.gd` | Easy State Machine state that plays an `idle` animation. |
| `res://scripts/ui/battle/combatant_static_state.gd` | Easy State Machine state that displays a single `static` frame. |

## Data resources

| Resource | Role |
| --- | --- |
| `res://data/characters/Warrior/warrior_visual_state_machine_config.tres` | Easy State Machine config for the warrior visual. |
| `res://data/enemies/Training_Ghoul/training_ghoul_visual_state_machine_config.tres` | Easy State Machine config for the Training Ghoul visual. |

## Scene pattern

Each visual scene should contain:

- A root `Control` with `CombatantBattleVisual`.
- An `AnimatedSprite2D` child.
- A `StateMachine` child using the Easy State Machine runtime script.
- One or more state nodes, usually `IdleState` or `StaticState`.
- A SpriteFrames resource under `res://assets/characters` or `res://assets/enemies`.

## See also

- [[Adding a battle visual]]
- [[Asset inventory]]
- [[Script inventory]]
