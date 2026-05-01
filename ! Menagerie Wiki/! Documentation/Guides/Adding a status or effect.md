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
   - `duration_seconds`
   - `outgoing_damage_multiplier`
   - `incoming_damage_multiplier`
4. Reference the status from an `ActionEffect` with `effect_id = &"status.apply"` and `status_id = &"status.<id>"`.

`CombatEffectLibrary.status_path_for_id()` resolves `status.<id>` to `res://core/statuses/<id>.tres`.

## Use an existing effect behavior

Prefer `ActionEffect` plus a namespaced `effect_id`:

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
4. Use exported fields already present on `ActionEffect` if they fit.
5. Add a new effect resource script only if the behavior needs fields that do not fit `ActionEffect`.
6. Update [[Key runtime APIs]], [[Resource inventory]], and any action guides using the effect.

## Validate behavior

- Confirm status labels update in `CombatantPanel`.
- Confirm outgoing/incoming multipliers affect `DamagePacket` before `take_damage()`.
- Confirm enemy AI estimates the effect if it should influence move choice.
- Run the headless load command after script/resource changes.

## See also

- [[Combat flow]]
- [[Data and resource model]]
- [[Key runtime APIs]]
- [[Adding a combat action]]
