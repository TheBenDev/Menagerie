---
title: Adding a status or effect
page-type: guide
status: draft
---

Use this guide to add reusable status data or new combat effect behavior.

## Add a status

1. Create a `StatusData` resource under `res://core/statuses`.
2. Use a short lowercase ID that matches the file name.
3. Set:
   - `id`
   - `display_name`
   - `description`
   - `icon_atlas_coords`
   - `icon_atlas_cell_size`
   - `duration_seconds`
   - `outgoing_damage_multiplier`
   - `incoming_damage_multiplier`
4. Use atlas coordinates from `res://assets/ui/global/icons/statuses/statuses_13.png` when the status should appear in the battle HUD status bar. The first status icon is `(0, 0)`, the second is `(1, 0)`, and unimplemented statuses can stay at `(-1, -1)`.
5. Open `res://scenes/combat/ui/StatusIconView.tscn` to visually preview icon sizing by changing `atlas_coords` and `atlas_cell_size`.
6. Reference the status from action `effect_data` with `id = &"status.apply"` and `status_id = &"status.<id>"`.

`CombatEffectLibrary.status_path_for_id()` resolves `status.<id>` to `res://core/statuses/<id>.tres`.

## Use an existing effect behavior

Prefer inline `effect_data` dictionaries with a namespaced `id`:

| Effect ID | Required fields |
| --- | --- |
| `combat.damage` | `base_damage`, `scaling_stat`, `scaling_multiplier` |
| `combat.block` | `amount` |
| `status.apply` | `status_id`, optional `duration_override_seconds` |
| `resource.rage.gain` | `amount` |
| `stat.strength.add` | `amount` |

## Add a new effect behavior

1. Add a new namespaced constant to `res://core/combat/actions/combat_effect_library.gd`.
2. Add the new ID to `apply_effect()`.
3. Add estimation behavior to `estimate_power()` if enemy AI should score it.
4. Read any new effect parameters from the dictionary with the existing `_data_*()` helpers.
5. Update [[Key runtime APIs]], [[Resource inventory]], and any action guides using the effect.

## Validate behavior

- Confirm the battle HUD status bar appears for player statuses and hides when no statuses remain.
- Confirm hovering the status icon shows the authored `description` in the battle info panel.
- Confirm outgoing/incoming multipliers affect `DamagePacket` before `take_damage()`.
- Confirm enemy AI estimates the effect if it should influence move choice.
- Run the headless load command after script/resource changes.

## See also

- [[Combat flow]]
- [[Data and resource model]]
- [[Key runtime APIs]]
- [[Adding a combat action]]
