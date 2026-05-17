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
| `DungeonMap.tscn` | `res://scenes/dungeon/dungeon_controller.gd` | Shows grid map progression, dungeon hotbar actions, persistent HP, and routed node encounters. |
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
2. `BattleScene` positions the current player, combat-only AI player copies, and generated enemy displays from authored `PlayerSlots` and `EnemySlots` markers before calling `CombatantDisplay.setup()`.
3. `BattleScene` configures player/enemy `CombatantGroup` values, including combat-only AI allies and generated enemies, then calls `hud.setup(battle, player_leader, primary_enemy, player_group, enemy_group)` for the primary bridge combatants.
4. `BattleActionBar` receives `player.actions` and updates the bottom hotbar buttons.
5. `BattleHUD` reads the player's active statuses and shows status icons in the transparent status bar above the hotbar.
6. `TimelineView` receives marker dictionaries derived from `battle.action_queue`.
7. Hover information from action resources, status resources, and `HoverInfoButton` nodes is exposed as hover metadata and rendered by the fixed info panel beside the hotbar.
8. `BattleHUD` emits `action_selected`, `speed_requested`, and `pause_requested`.
9. `BattleScene` turns manual single-target `action_selected` events into explicit target selection. `Self`, `AllAllies`, and `AllEnemies` actions queue immediately without target picking. While targeting, `BattleHUD.set_targeting_active(true)` disables further action-slot selection without disabling speed or pause controls.
10. `CombatantDisplay` nodes show a target highlight when valid and emit `target_selected(combatant)` on left click.
11. Confirming a target calls `BattleController.player_choose_action(action, [target])`. The HUD still renders the primary player action bar until later phases add multi-combatant controls.

## Dungeon Map HUD Flow

1. `DungeonController` builds generated map nodes and keeps reveal/selectable state in sync with `RunData`.
2. The dungeon hotbar layers solid art, three action slots, the persistent player HP bar, and transparent frame art.
3. The HP bar reads `GameManager.get_run_player_hp_snapshot()` so encounter damage and combat results carry back to the map, and its overlay label shows current/max HP on hover.
4. The three action slots read from `GameManager.get_dungeon_abilities()`, which uses the class-agnostic default dungeon ability pool.
5. `DungeonMap.tscn` places `PawnLayer` above `NodeLayer`; `DungeonController` fills it with `DungeonMapPawnView` markers that display active pawn positions from `RunData`.
6. Node buttons request selected-pawn travel orders through `RunData`; accepted local-leader orders can also assign same-destination follow orders to active `AutoPilot` pawns.
7. The controller travel loop advances active pawn travel state one node step at a time, applies arrival visit/reveal behavior, and marker positions refresh from that state.

## Shared controls

| Control/helper | Source | Role |
| --- | --- | --- |
| `ResourceBar` | `res://scenes/ui/common/resource_bar.gd` | Draws labeled resource meters with optional reference/bonus text. |
| `TimeProgressBar` | `res://scenes/ui/common/time_progress_bar.gd` | Draws the run timer fill inside the timer fill node's bounds. |
| `NumberFont` | `res://scenes/ui/common/number_font.gd` | Applies or draws shared-font number spans in mixed-width UI text. |
| `TimelineView` | `res://scenes/combat/timeline_view.gd` | Draws and scrolls the battle timeline ruler and action markers. |
| `DungeonMapInputConnector` | `res://scenes/dungeon/dungeon_map_input_connector.gd` | Connects shared map navigation keybinds to dungeon zooming and panning. |
| `DungeonMapPawnView` | `res://scenes/dungeon/dungeon_map_pawn_view.gd` | Draws one display-only dungeon pawn marker from run-owned pawn state. |

## See also

- [[Scene routes]]
- [[Adding a HUD element]]
- [[Script inventory]]
- [[Signals and events]]
