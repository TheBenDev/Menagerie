---
title: UI flow
page-type: guide
status: draft
---

The UI layer is scene-driven: scene scripts call `GameManager`, reusable controls render runtime state, and HUDs subscribe to signals.

## Scene UI

| Scene | Script | Role |
| --- | --- | --- |
| `MainMenu.tscn` | `res://scenes/ui/main_menu/main_menu.gd` | Routes to waiting room, handles escape/close, requests menu music. |
| `WaitingRoom.tscn` | `res://scenes/ui/waiting_room/waiting_room.gd` | Selects character/difficulty and starts runs. |
| `DungeonMap.tscn` | `res://scenes/dungeon/dungeon_controller.gd` | Shows grid map progression and starts routed node encounters. |
| `BattleScene.tscn` | `res://scenes/combat/battle_scene.gd` | Coordinates combat and owns combat background, combatant displays, and HUD composition. |
| `BattleHUD.tscn` | `res://scenes/combat/ui/battle_hud.gd` | Shows combat UI, timeline, bottom hotbar, time controls, and the combat `GlobalHUD` child. |
| `UI/GlobalHUD/GlobalHUD.tscn` | `res://scenes/ui/global_hud/global_hud.gd` | Shows run timer, currencies, and selected character stats. |
| `RunSummary.tscn` | `res://scenes/ui/run_summary/run_summary.gd` | Shows final run stats and returns to waiting room. |

## Global HUD flow

1. `GlobalHUD` is a `CanvasLayer` scene instantiated by route scenes or embedded as the `BattleHUD` child during combat.
2. It connects to `GameManager.run_time_changed` and `GameManager.run_currencies_changed`.
3. It reads selected profile data with `GameManager.get_selected_character_profile()`.
4. It formats time, memory, gold, and stat values for display.

## Battle HUD flow

1. `BattleScene` is the combat scene root and owns the battle controller, combatants, background, combatant displays, and HUD.
2. `BattleScene` calls `hud.setup(battle, warrior, enemy)` and `CombatantDisplay.setup()` for the warrior and enemy displays.
3. `BattleActionBar` receives `player.actions` and updates the bottom hotbar buttons.
4. `BattleHUD` reads the player's active statuses and shows status icons in the transparent status bar above the hotbar.
5. `TimelineView` receives marker dictionaries derived from `battle.action_queue`.
6. Hover information from action resources, status resources, and `HoverInfoButton` nodes is exposed as hover metadata and rendered by the fixed info panel beside the hotbar.
7. `BattleHUD` emits `action_selected`, `speed_requested`, and `pause_requested`.
8. `BattleScene` handles those signals and calls `BattleController`.

## Shared controls

| Control/helper | Source | Role |
| --- | --- | --- |
| `ResourceBar` | `res://scenes/ui/common/resource_bar.gd` | Draws labeled resource meters with optional reference/bonus text. |
| `TimeProgressBar` | `res://scenes/ui/common/time_progress_bar.gd` | Draws the run timer fill inside the timer fill node's bounds. |
| `NumberFont` | `res://scenes/ui/common/number_font.gd` | Applies or draws shared-font number spans in mixed-width UI text. |
| `TimelineView` | `res://scenes/combat/timeline_view.gd` | Draws and scrolls the battle timeline ruler and action markers. |
| `DungeonMapInputConnector` | `res://scenes/dungeon/dungeon_map_input_connector.gd` | Connects shared map navigation keybinds to dungeon zooming and panning. |

## See also

- [[Scene routes]]
- [[Adding a HUD element]]
- [[Script inventory]]
- [[Signals and events]]
