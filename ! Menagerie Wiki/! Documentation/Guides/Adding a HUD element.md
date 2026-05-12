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
| `BattleHUD` | Current battle state, action choice, timeline, hotbar, and time controls. |
| `CombatantDisplay` | Per-combatant battle visual, health, class resource, statuses, and identity. |
| `ActionQueuePanel` | Pending/resolved action queue display. |
| `TimelineView` | Visual combat timeline ruler and action markers. |

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
   - `CombatantDisplay.refresh()`
4. Keep layout dimensions stable so changing text does not shift battle controls.

## Hover info

Use `HoverInfoPanel` for fixed-position hover details instead of mouse tooltips.

1. Put static button text on a `HoverInfoButton` with `hover_info_title`, `hover_info_description`, and optional `hover_info_details`.
2. For dynamic controls, set `hover_info_title`, `hover_info_description`, or `hover_info_details` metadata on the hovered `Control`.
3. Call `HoverInfoPanel.bind_source(control)` so the panel can render that control's metadata on hover.
4. Prefer authored resource descriptions, such as `CombatActionData.description` and `StatusData.description`, over formatting item-specific text in hover handlers.

## Resource bars

For combatant resources:

1. Add a `ResourceBarConfig` to the combatant profile.
2. Implement or extend `Combatant.get_resource_snapshot(resource_id)`.
3. Update the relevant authored resource bar slot in `CombatantDisplay.tscn` or `BattleHUD.tscn`.
4. Refresh the bar through the owning display or HUD script.

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
