---
title: UI flow
page-type: guide
status: draft
---

The UI layer is scene-driven: scene scripts call `GameManager`, reusable controls render runtime state, and HUDs subscribe to signals.

## Scene UI

| Scene | Script | Role |
| --- | --- | --- |
| `main_menu.tscn` | `res://scenes/ui/main_menu/main_menu.gd` | Routes to waiting room, handles escape/close, requests menu music. |
| `waiting_room.tscn` | `res://scenes/ui/waiting_room/waiting_room.gd` | Selects character/difficulty and starts runs. |
| `dungeon.tscn` | `res://scenes/dungeon/dungeon_controller.gd` | Shows map progression and starts encounters. |
| `Battle/UI/BattleHUD.tscn` | `res://scenes/combat/ui/battle_hud.gd` | Shows combat state, timeline, panels, action bar, and time controls. |
| `UI/GlobalHUD/GlobalHUD.tscn` | `res://scenes/ui/global_hud/global_hud.gd` | Shows run timer, currencies, and selected character stats. |
| `run_summary.tscn` | `res://scenes/ui/run_summary/run_summary.gd` | Shows final run stats and returns to waiting room. |

## Global HUD flow

1. `GlobalHUD` is a `CanvasLayer` scene instantiated by route scenes.
2. It connects to `GameManager.run_time_changed` and `GameManager.run_currencies_changed`.
3. It reads selected profile data with `GameManager.get_selected_character_profile()`.
4. It formats time, memory, gold, and stat values for display.

## Battle HUD flow

1. `BattleScene` calls `hud.setup(battle, warrior, enemy)`.
2. `BattleHUD` sets up the player and enemy `CombatantPanel`s.
3. `BattleActionBar` receives `player.actions`.
4. `TimelineView` receives marker dictionaries derived from `battle.action_queue`.
5. `ActionQueuePanel` renders pending/resolved queue entries.
6. `BattleHUD` emits `action_selected`, `speed_requested`, and `pause_requested`.
7. `BattleScene` handles those signals and calls `BattleController`.

## Shared controls

| Control/helper | Source | Role |
| --- | --- | --- |
| `ResourceBar` | `res://scenes/ui/common/resource_bar.gd` | Draws labeled resource meters with optional reference/bonus text. |
| `TimeProgressBar` | `res://scenes/ui/common/time_progress_bar.gd` | Draws the run timer fill inside an authored frame. |
| `NumberFont` | `res://scenes/ui/common/number_font.gd` | Applies or draws monospaced number spans in mixed-width UI text. |
| `TimelineView` | `res://scenes/combat/timeline_view.gd` | Draws and scrolls battle timeline markers. |

## See also

- [[Scene routes]]
- [[Adding a HUD element]]
- [[Script inventory]]
- [[Signals and events]]
