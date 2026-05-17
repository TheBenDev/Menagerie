---
title: Signals and events
page-type: reference
status: draft
---

Signals are the main event contract between combat, UI, audio, and run state.

## GameManager

| Signal | Payload | Consumers |
| --- | --- | --- |
| `run_time_changed` | `remaining_time_seconds: float`, `max_time_seconds: float` | `GlobalHUD._on_run_time_changed()` |
| `run_currencies_changed` | `memories: int`, `gold: int` | `GlobalHUD._on_run_currencies_changed()` |
| `run_ended` | `reason: String` | `BattleScene._on_run_ended()` |

## BattleController

| Signal | Payload | Consumers |
| --- | --- | --- |
| `time_changed` | `current_time: float` | `BattleScene._refresh_hud()`, `BattleScene._on_battle_time_changed()`, `CombatAudioBridge._on_battle_state_changed()` |
| `player_ready` | `player: Combatant` | `BattleScene._refresh_hud()`, `CombatAudioBridge._on_battle_state_changed()` |
| `player_group_defeated` | none | `BattleScene._on_player_group_defeated()` |
| `enemy_group_defeated` | none | `BattleScene._on_enemy_group_defeated()` |
| `battle_log` | `message: String` | `BattleScene._refresh_hud()` |
| `time_scale_changed` | `time_scale: float` | `BattleScene._refresh_hud()` |
| `pause_changed` | `is_paused: bool` | `BattleScene._refresh_hud()` |
| `action_queue_changed` | none | `BattleScene._refresh_hud()`, `CombatAudioBridge._on_battle_state_changed()` |

## Combatant

| Signal | Payload | Consumers |
| --- | --- | --- |
| `hp_changed` | `combatant: Combatant` | HUD refresh, audio hit snapshots, run result calculations. |
| `block_changed` | `combatant: Combatant` | HUD refresh, audio block snapshots. |
| `statuses_changed` | `combatant: Combatant` | HUD refresh and status label updates. |
| `died` | `combatant: Combatant` | `BattleController` group defeat checks, `BattleScene` HUD refresh, `CombatAudioBridge` death SFX. |
| `action_started` | `combatant: Combatant`, `action: CombatActionData` | HUD refresh and action start SFX. |
| `action_resolved` | `combatant: Combatant`, `action: CombatActionData` | HUD refresh and action resolve SFX. |

## WarriorCombatant

| Signal | Payload | Consumers |
| --- | --- | --- |
| `rage_changed` | `combatant: WarriorCombatant` | `BattleScene._refresh_hud()` via dynamic signal check. |

## Battle UI

| Emitter | Signal | Payload | Consumer |
| --- | --- | --- | --- |
| `BattleHUD` | `action_selected` | `index: int` | `BattleScene._choose_player_action()` |
| `BattleHUD` | `hotbar_slot_used` | `slot_id: StringName`, `slot_entry: Dictionary` | Future inventory or loadout consumers. |
| `BattleHUD` | `speed_requested` | none | `BattleScene._on_speed_requested()` |
| `BattleHUD` | `pause_requested` | none | `BattleScene._on_pause_requested()` |
| `BattleActionBar` | `slot_selected` | `slot_id: StringName` | `BattleHUD._on_hotbar_slot_selected()` |
| `BattleActionBar` | `slot_hovered` | `source: Control` | `BattleHUD._show_hover_info_for_source()` |
| `BattleActionBar` | `slot_hover_ended` | none | `BattleHUD._clear_hover_info()` |
| `CombatantDisplay` | `target_selected` | `combatant: Combatant` | `BattleScene._on_target_display_selected()` during explicit player targeting. |
| `CombatantBattleVisual` | `visual_bounds_changed` | `bounds: Rect2` | Available for visual-bound consumers; no current HUD consumer. |

## Button and route events

| Source | Event | Effect |
| --- | --- | --- |
| `MainMenu` buttons | `pressed` | Routes to waiting room, quits, or handles escape. |
| `WaitingRoom` buttons | `pressed` | Selects difficulty, starts run, or routes back. |
| `DungeonNodeView` buttons | `pressed` | `DungeonController` requests path-based travel for the selected pawn. Movement and node entry are handled by the travel loop and arrival handler. |
| `DungeonController` | `node_event_emitted(event: Dictionary)` | Emitted for every visited dungeon node type. |
| `DungeonController` | `empty_node_entered(node_id: int)` | Emitted when an Empty node is entered before it auto-resolves. |
| `DungeonController` | `haven_node_entered(node_id: int)` | Emitted when Haven is entered, including the initial occupied Haven state. |
| `DungeonController` | `node_completed(node_id: int, node_type: String)` | Emitted when a node is newly resolved locally. |
| Encounter scene | `encounter_finished(result: Dictionary)` | `DungeonController` applies supported completion results, clears the scene, resolves the node, and unlocks participating pawns. Unsupported modes keep the encounter active. |
| `SoundManager` button hook | `BaseButton.pressed` | Plays `ui.button.click` for existing and newly-added buttons. |

## Dungeon node events

| Node type | Current behavior |
| --- | --- |
| `Haven` | Starts revealed/visited/occupied but unresolved, emits node-entry and Haven-entry signals, and remains unresolved until future Haven behavior defines completion. |
| `Empty` | Marks visited, emits node-entry and Empty-entry signals, reveals connected neighbors, then resolves immediately. |
| `Encounter` | Marks visited, emits a node event, reveals connected neighbors, locks the entering pawn, loads the encounter scene by `encounter_id`, and resolves after a supported `encounter_finished` completion result. |
| `Fight` | Marks visited, emits a node event containing `combat_encounter_id`, `combat_encounter_profile_path`, and generated `enemy_instances`, locks the entering pawn, and routes through `GameManager.start_combat()`. Resolution waits for a victorious combat result. |
| `Boss` | Marks visited, emits a node event containing `combat_encounter_id`, `combat_encounter_profile_path`, and generated `enemy_instances`, locks the entering pawn, and routes through `GameManager.start_combat()`. Resolution waits for the boss combat result. |

## Event locks

Unresolved Fight, Boss, and Encounter nodes lock only the pawn that entered the node. Event completion resolves the node for pathing, unlocks pawns whose `active_event_node_id` matches that node, and leaves those pawns on the now-resolved node. Non-participating pawns are not locked or unlocked by that event.

## See also

- [[Run flow]]
- [[Combat flow]]
- [[Audio flow]]
- [[Signal reference template]]
