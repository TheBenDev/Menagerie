---
title: Script inventory
page-type: reference
status: draft
---

This inventory lists every runtime `.gd` script under `res://scripts`, grouped by subsystem.

## Totals

| Group | Count |
| --- | ---: |
| `scripts/audio` | 3 |
| `scripts/combat` | 13 |
| `scripts/data` | 20 |
| `scripts/dungeon` | 3 |
| `scripts/ui` | 14 |
| Root scripts | 2 |
| Total | 55 |

## Root scripts

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scripts/game_manager.gd` | Autoload, no `class_name` | Owns run setup, scene transitions, rewards, timers, and scene music routing. |
| `res://scripts/run_data.gd` | `RunData` | Stores mutable run state, selected setup, timer, encounters, rewards, and combat totals. |

## Audio

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scripts/audio/audio_registry.gd` | `AudioRegistry` | Scans `res://sounds` and exposes streams by stable IDs derived from paths. |
| `res://scripts/audio/combat_audio_bridge.gd` | None | Bridges combat signals to SFX and adaptive music states. |
| `res://scripts/audio/sound_manager.gd` | Autoload, no `class_name` | Registers cues, plays SFX/UI sounds, crossfades music, manages runtime buses. |

## Combat

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scripts/combat/actions/action_resolver.gd` | `ActionResolver` | Applies action costs and effects. |
| `res://scripts/combat/actions/combat_effect_library.gd` | `CombatEffectLibrary` | Resolves namespaced effect IDs and shared runtime effect behavior. |
| `res://scripts/combat/actions/queued_action.gd` | `QueuedAction` | Represents timeline queue entries, status, resolution order, and tie rolls. |
| `res://scripts/combat/ai/enemy_brain.gd` | `EnemyBrain` | Chooses enemy actions and targets using authored move weights and difficulty scoring. |
| `res://scripts/combat/battle/battle_controller.gd` | `BattleController` | Advances combat time, queues actions, resolves simultaneous actions, requests player input. |
| `res://scripts/combat/battle/battle_scene.gd` | None | Wires combatants, HUD, audio, run data, and final combat result reporting. |
| `res://scripts/combat/combat_result.gd` | `CombatResult` | Encounter result used by run progress, rewards, and summary UI. |
| `res://scripts/combat/combatants/combatant.gd` | `Combatant` | Base combatant stats, resources, statuses, action state, and damage handling. |
| `res://scripts/combat/combatants/enemy_combatant.gd` | `EnemyCombatant` | Marks itself as an enemy before applying profile data. |
| `res://scripts/combat/combatants/warrior_combatant.gd` | `WarriorCombatant` | Adds rage gain/decay and rage resource snapshots. |
| `res://scripts/combat/damage/damage_packet.gd` | `DamagePacket` | Carries source, target, amount, and tags before damage is applied. |
| `res://scripts/combat/time/combat_time.gd` | `CombatTime` | Snaps combat timing to fixed ticks and formats durations. |
| `res://scripts/combat/timeline/timeline_view.gd` | `TimelineView` | Draws and scrolls combat action timeline markers. |

## Data resource scripts

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scripts/data/actions/combat_action_data.gd` | `CombatActionData` | Base combat action resource fields. |
| `res://scripts/data/actions/combat_moveset_data.gd` | `CombatMovesetData` | Container for actions available to a profile. |
| `res://scripts/data/actions/enemy_move_data.gd` | `EnemyMoveData` | Enemy action data with AI weights, target rules, HP gates, and role metadata. |
| `res://scripts/data/actions/player_action_data.gd` | `PlayerActionData` | Player action fields for rage, stance, action bar visibility, and tooltip. |
| `res://scripts/data/ai/enemy_ai_profile.gd` | `EnemyAIProfile` | Enemy move list and behavior mode. |
| `res://scripts/data/audio/audio_cue_data.gd` | `AudioCueData` | Sound cue streams, bus, volume, pitch, cooldown, instances, and priority. |
| `res://scripts/data/audio/audio_library_data.gd` | `AudioLibraryData` | Catalog for authored cues and music tracks. |
| `res://scripts/data/audio/music_state_data.gd` | `MusicStateData` | Adaptive music state variant. |
| `res://scripts/data/audio/music_track_data.gd` | `MusicTrackData` | Music track, playlist, state variants, bus, volume, fades, and looping. |
| `res://scripts/data/combatants/combatant_profile.gd` | `CombatantProfile` | Identity, stats, moveset, rewards, AI, SFX IDs, and UI bars. |
| `res://scripts/data/difficulty/difficulty_profile.gd` | `DifficultyProfile` | Enemy stat/reward multipliers and AI tuning values. |
| `res://scripts/data/effects/action_effect.gd` | `ActionEffect` | Namespaced data effect resolved by `CombatEffectLibrary`. |
| `res://scripts/data/effects/apply_status_effect.gd` | `ApplyStatusEffect` | Direct status-application effect variant. |
| `res://scripts/data/effects/block_effect.gd` | `BlockEffect` | Direct block-granting effect variant. |
| `res://scripts/data/effects/damage_effect.gd` | `DamageEffect` | Direct stat-scaled damage effect variant. |
| `res://scripts/data/effects/rage_gain_effect.gd` | `RageGainEffect` | Direct rage-gain effect variant. |
| `res://scripts/data/effects/strength_increase_effect.gd` | `StrengthIncreaseEffect` | Direct strength adjustment effect variant. |
| `res://scripts/data/rewards/reward_profile.gd` | `RewardProfile` | Base memory/gold rewards and boss multiplier. |
| `res://scripts/data/status/status_data.gd` | `StatusData` | Timed status and outgoing/incoming damage multipliers. |
| `res://scripts/data/ui/resource_bar_config.gd` | `ResourceBarConfig` | Combatant resource bar display config. |

## Dungeon

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scripts/dungeon/dungeon_controller.gd` | None | Controls dungeon progression, applies combat results, starts encounters. |
| `res://scripts/dungeon/dungeon_node_data.gd` | `DungeonNodeData` | Runtime dungeon node state for visited/revealed/connected nodes. |
| `res://scripts/dungeon/dungeon_node_view.gd` | `DungeonNodeView` | Button view for dungeon nodes and selection tooltips. |

## UI

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scripts/ui/battle/action_bar.gd` | `BattleActionBar` | Displays player actions and emits selected action indexes. |
| `res://scripts/ui/battle/action_queue_panel.gd` | `ActionQueuePanel` | Renders pending and resolved combat actions. |
| `res://scripts/ui/battle/battle_hud.gd` | `BattleHUD` | Coordinates combatant panels, action buttons, timeline, and time controls. |
| `res://scripts/ui/battle/combatant_panel.gd` | `CombatantPanel` | Shows one combatant's name, art, health, resources, and statuses. |
| `res://scripts/ui/battle/combatant_static_state.gd` | `CombatantStaticState` | Easy State Machine state that shows one static frame. |
| `res://scripts/ui/battle/warrior_battle_visual.gd` | `CombatantBattleVisual` | Fits battle sprite visuals inside a control. |
| `res://scripts/ui/battle/warrior_idle_state.gd` | `WarriorIdleState` | Easy State Machine state that plays idle animation. |
| `res://scripts/ui/common/number_font.gd` | `NumberFont` | Applies and draws monospaced numeric spans. |
| `res://scripts/ui/common/resource_bar.gd` | None | Custom resource meter control. |
| `res://scripts/ui/common/time_progress_bar.gd` | `TimeProgressBar` | Draws run timer fill inside authored frame proportions. |
| `res://scripts/ui/global_hud.gd` | None | Persistent HUD layer for timer, currencies, and selected character stats. |
| `res://scripts/ui/main_menu.gd` | None | Main menu routing and button handling. |
| `res://scripts/ui/run_summary.gd` | None | Final run stats and memory export UI. |
| `res://scripts/ui/waiting_room.gd` | None | Character/difficulty selection before dungeon run. |

## See also

- [[Key runtime APIs]]
- [[Resource inventory]]
- [[Signals and events]]
- [[Documentation workflow]]
