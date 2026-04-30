---
title: Adding a HUD element
page-type: guide
status: draft
---

Use this guide to add or extend HUD UI without breaking the signal-driven refresh flow.

## Pick the HUD

| HUD | Use for |
| --- | --- |
| `GlobalHUD` | Run timer, currencies, selected character stats, persistent run-level data. |
| `BattleHUD` | Current battle state, action choice, timeline, combatants, queue, time controls. |
| `CombatantPanel` | Per-combatant health, resources, statuses, identity, visual surface. |
| `ActionQueuePanel` | Pending/resolved action queue display. |
| `TimelineView` | Visual timeline markers. |

## Add data first

1. Identify the source of truth: `GameManager`, `RunData`, `BattleController`, `Combatant`, or resource data.
2. Prefer reading through existing public methods or snapshots.
3. If the value changes over time, connect to an existing signal or add a focused new signal.

## Add the UI

1. Edit `.tscn` scenes through Godot when possible.
2. Add `@onready` references in the owning script.
3. Update the existing refresh method:
   - `GlobalHUD._refresh_all()`
   - `BattleHUD.refresh()`
   - `CombatantPanel.refresh()`
4. Keep layout dimensions stable so changing text does not shift battle controls.

## Resource bars

For combatant resources:

1. Add a `ResourceBarConfig` to the combatant profile.
2. Implement or extend `Combatant.get_resource_snapshot(resource_id)`.
3. Let `CombatantPanel` build and refresh the extra bar.

## Validate behavior

- Confirm the UI updates after the correct signal.
- Confirm it renders at battle start and after state changes.
- Confirm the scene still loads headlessly.
- For battle UI, test waiting, advancing, paused, and battle-over states.

## See also

- [[UI flow]]
- [[Signals and events]]
- [[Resource inventory]]
- [[Script inventory]]
