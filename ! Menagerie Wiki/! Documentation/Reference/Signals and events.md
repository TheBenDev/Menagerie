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
| `died` | `combatant: Combatant` | `BattleController`, `BattleScene`, `CombatAudioBridge`. |
| `action_started` | `combatant: Combatant`, `action: CombatActionData` | HUD refresh and action start SFX. |
| `action_resolved` | `combatant: Combatant`, `action: CombatActionData` | HUD refresh and action resolve SFX. |

## WarriorCombatant

| Signal | Payload | Consumers |
| --- | --- | --- |
| `rage_changed` | `combatant: WarriorCombatant` | `BattleScene._refresh_hud()` via dynamic signal check. |

## Battle UI

| Emitter | Signal | Payload | Consumer |
| --- | --- | --- | --- |
| `BattleHUD` | `action_selected` | `index: int` | `BattleScene._choose_warrior_action()` |
| `BattleHUD` | `speed_requested` | none | `BattleScene._on_speed_requested()` |
| `BattleHUD` | `pause_requested` | none | `BattleScene._on_pause_requested()` |
| `BattleActionBar` | `action_selected` | `index: int` | `BattleHUD._on_action_selected()` |

## Button and route events

| Source | Event | Effect |
| --- | --- | --- |
| `MainMenu` buttons | `pressed` | Routes to waiting room, quits, or handles escape. |
| `WaitingRoom` buttons | `pressed` | Selects difficulty, starts run, or routes back. |
| `DungeonNodeView` buttons | `pressed` | `DungeonController` starts reachable encounters. |
| `SoundManager` button hook | `BaseButton.pressed` | Plays `ui.button.click` for existing and newly-added buttons. |

## See also

- [[Run flow]]
- [[Combat flow]]
- [[Audio flow]]
- [[Signal reference template]]
