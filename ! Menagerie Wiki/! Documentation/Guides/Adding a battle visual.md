---
title: Adding a battle visual
page-type: guide
status: draft
---

Use this guide to add a character or enemy battle visual scene.

## Add visual assets

1. Put source sprites under:
   - `res://assets/characters/<Name>` for playable characters.
   - `res://assets/enemies/<name>` for enemies.
2. Create or update a `SpriteFrames` resource.
3. Use animation names expected by state scripts, such as `idle` or `static`.

## Create the visual scene

Use existing scenes as patterns:

- `res://scenes/Battle/WarriorBattleVisual.tscn`
- `res://scenes/Battle/TrainingGhoulBattleVisual.tscn`

The scene should contain:

- Root `Control` with `CombatantBattleVisual`.
- `AnimatedSprite2D`.
- `StateMachine`.
- State nodes such as `IdleState` or `StaticState`.
- An Easy State Machine `SMConfig` resource under `res://data/...`.

## Configure fitting

`CombatantBattleVisual` exposes:

| Property | Meaning |
| --- | --- |
| `sprite_node_path` | Path to the `AnimatedSprite2D`. |
| `fill_ratio` | Percent of available control space the sprite can occupy. |
| `bottom_padding` | Pixels reserved at bottom of the control. |
| `visual_offset` | Final sprite position offset. |

## Wire into battle UI

1. Open `res://scenes/Battle/UI/BattleHUD.tscn` in Godot.
2. Replace or add the visual scene where the combatant panel expects it.
3. Keep node paths used by `battle_hud.gd` and `combatant_panel.gd` stable unless you update the scripts.

## Validate behavior

- Confirm the scene loads without missing resources.
- Confirm `AnimatedSprite2D` has the animation used by state scripts.
- Confirm the visual is framed correctly in the battle HUD.
- Run the headless load command after scene/resource/script changes.

## See also

- [[Battle visuals]]
- [[Asset inventory]]
- [[Adding a HUD element]]
- [[Script inventory]]
