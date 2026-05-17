---
title: Script inventory
page-type: reference
status: draft
---

This inventory lists runtime `.gd` scripts under `res://core` and `res://scenes`, grouped by subsystem.

## Totals

| Group | Count |
| --- | ---: |
| `core/audio` | 7 |
| `core/combat` | 15 |
| `core/dungeon` | 14 |
| `core/input` | 1 |
| `core/party` | 3 |
| `core/difficulty`, `core/rewards`, `core/statuses` | 3 |
| `scenes/combat` | 6 |
| `scenes/combatants` | 8 |
| `scenes/dungeon` | 6 |
| `scenes/ui` | 8 |
| Root scripts | 2 |
| Total | 73 |

## Root scripts

| Script | Class | Purpose |
| --- | --- | --- |
| `res://core/game_manager.gd` | Autoload, no `class_name` | Owns run setup, scene transitions, rewards, timers, and scene music routing. |
| `res://core/run_data.gd` | `RunData` | Stores mutable run state, selected setup, timer, encounters, rewards, and combat totals. |

## Input

| Script | Class | Purpose |
| --- | --- | --- |
| `res://core/input/keybinds_helper.gd` | `KeybindsHelper` | Converts raw mouse/keybind events into semantic map navigation actions. |

## Audio

| Script | Class | Purpose |
| --- | --- | --- |
| `res://core/audio/audio_registry.gd` | `AudioRegistry` | Scans `res://assets/audio`, exposes stable IDs from paths, and lazy-loads streams on first use. |
| `res://core/audio/combat_audio_bridge.gd` | None | Bridges combat signals to SFX and adaptive music states. |
| `res://core/audio/sound_manager.gd` | Autoload, no `class_name` | Registers cues, plays SFX/UI sounds, crossfades music, manages runtime buses. |

## Combat

| Script | Class | Purpose |
| --- | --- | --- |
| `res://core/combat/actions/action_resolver.gd` | `ActionResolver` | Applies action costs and effect data. |
| `res://core/combat/actions/combat_effect_library.gd` | `CombatEffectLibrary` | Resolves namespaced effect IDs and shared runtime effect behavior. |
| `res://core/combat/actions/queued_action.gd` | `QueuedAction` | Represents timeline queue entries, status, resolution order, and tie rolls. |
| `res://core/combat/ai/enemy_brain.gd` | `EnemyBrain` | Chooses enemy actions and targets using authored move weights and difficulty scoring. |
| `res://core/combat/battle/battle_controller.gd` | `BattleController` | Advances combat time, queues actions, resolves simultaneous actions, requests player input. |
| `res://core/combat/combatant_group.gd` | `CombatantGroup` | Temporary combat-side container for player or enemy combatants in battle. |
| `res://core/combat/combatant_state.gd` | `CombatantState` | Persistent runtime combat state for combat-capable characters or enemies. |
| `res://scenes/combat/battle_scene.gd` | None | Wires combatants, targeting, HUD, audio, run data, and final combat result reporting. |
| `res://core/combat/combat_result.gd` | `CombatResult` | Encounter result used by run progress, rewards, and summary UI. |
| `res://scenes/combatants/combatant.gd` | `Combatant` | Base combatant stats, resources, statuses, action state, and damage handling. |
| `res://scenes/combatants/combatant_animation_state_helper.gd` | `CombatantAnimationStateHelper` | Shared helper for combatant animation state scripts. |
| `res://scenes/combatants/combatant_battle_visual.gd` | `CombatantBattleVisual` | Fits battle sprite visuals inside a control. |
| `res://scenes/combatants/combatant_static_state.gd` | `CombatantStaticState` | Easy State Machine state that shows one static frame. |
| `res://scenes/combatants/enemies/enemy_combatant.gd` | `EnemyCombatant` | Enemy combatant specialization used for type-specific references. |
| `res://scenes/combatants/characters/warrior/warrior_combatant.gd` | `WarriorCombatant` | Adds rage gain/decay and rage resource snapshots. |
| `res://scenes/combatants/characters/warrior/states/warrior_idle_state.gd` | `WarriorIdleState` | Warrior Easy State Machine state that plays idle animation. |
| `res://core/combat/damage/damage_packet.gd` | `DamagePacket` | Carries source, target, and amount before damage is applied. |
| `res://core/combat/time/combat_time.gd` | `CombatTime` | Snaps combat timing to fixed ticks and formats durations. |
| `res://scenes/combat/timeline_view.gd` | `TimelineView` | Draws and scrolls the combat timeline ruler and action markers. |

## Data resource scripts

| Script | Class | Purpose |
| --- | --- | --- |
| `res://core/combat/actions/combat_action_data.gd` | `CombatActionData` | Base combat action resource fields and hover description. |
| `res://core/combat/actions/combat_moveset_data.gd` | `CombatMovesetData` | Container for actions available to a profile. |
| `res://core/combat/actions/enemy_move_data.gd` | `EnemyMoveData` | Enemy action data with AI weights, target rules, HP gates, and role metadata. |
| `res://core/combat/actions/player_action_data.gd` | `PlayerActionData` | Player action fields for rage, stance, action bar visibility, and tooltip. |
| `res://core/combat/ai/enemy_ai_profile.gd` | `EnemyAIProfile` | Enemy move list and behavior mode. |
| `res://core/audio/audio_cue_data.gd` | `AudioCueData` | Sound cue streams, bus, volume, pitch, cooldown, instances, and priority. |
| `res://core/audio/audio_library_data.gd` | `AudioLibraryData` | Catalog for authored cues and music tracks. |
| `res://core/audio/music_state_data.gd` | `MusicStateData` | Adaptive music state variant. |
| `res://core/audio/music_track_data.gd` | `MusicTrackData` | Music track, playlist, state variants, bus, volume, fades, and looping. |
| `res://scenes/combatants/combatant_profile.gd` | `CombatantProfile` | Identity, stats, moveset, rewards, AI, SFX IDs, and UI bars. |
| `res://core/party/party_control_mode.gd` | `PartyControlMode` | Party control mode enum and behavior helpers. |
| `res://core/party/player_party_member_state.gd` | `PlayerPartyMemberState` | Player-party wrapper around one reusable combatant state. |
| `res://core/party/player_party_state.gd` | `PlayerPartyState` | Player-owned roster, active member IDs, leader, and selected member. |
| `res://core/difficulty/difficulty_profile.gd` | `DifficultyProfile` | Enemy stat/reward multipliers and AI tuning values. |
| `res://core/rewards/reward_profile.gd` | `RewardProfile` | Base memory/gold rewards and boss multiplier. |
| `res://core/statuses/status_data.gd` | `StatusData` | Timed status hover description, atlas coordinates, and outgoing/incoming damage multipliers. |
| `res://scenes/ui/common/resource_bar_config.gd` | `ResourceBarConfig` | Combatant resource bar display config. |

## Dungeon

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scenes/dungeon/dungeon_controller.gd` | None | Builds dungeon grid nodes, controls reveal state, refreshes dungeon hotbar HP/action slots, applies combat results, and starts routed encounters. |
| `res://core/dungeon/abilities/dungeon_ability_data.gd` | `DungeonAbilityData` | Class-agnostic dungeon hotbar ability metadata. |
| `res://core/dungeon/abilities/dungeon_ability_pool.gd` | `DungeonAbilityPool` | Ordered pool of dungeon map abilities for the hotbar. |
| `res://core/dungeon/dungeon_map_pawn_state.gd` | `DungeonMapPawnState` | Run-owned dungeon map position, travel orders, and event-lock state for one active party member. |
| `res://core/dungeon/dungeon_movement_coordinator.gd` | `DungeonMovementCoordinator` | Advances active dungeon pawn travel orders in synchronized node steps. |
| `res://core/dungeon/dungeon_pathfinder.gd` | `DungeonPathfinder` | Finds allowed routes through descriptor connection graphs. |
| `res://core/dungeon/dungeon_floor_generation_config.gd` | `DungeonFloorGenerationConfig` | Resource tuning profile for deterministic dungeon generation. |
| `res://core/dungeon/dungeon_floor_generator.gd` | `DungeonFloorGenerator` | Builds seeded dungeon descriptor arrays and validates generated graph data. |
| `res://core/dungeon/dungeon_node_data.gd` | `DungeonNodeData` | Runtime dungeon node state for grid placement, visited/revealed state, and connections. |
| `res://core/dungeon/dungeon_node_event_helper.gd` | `DungeonNodeEventHelper` | Builds and processes shared dungeon node visit event payloads. |
| `res://core/dungeon/encounters/dungeon_encounter_data.gd` | `DungeonEncounterData` | Authored encounter metadata, valid floors, optional scene override, and inline choices. |
| `res://core/dungeon/encounters/dungeon_encounter_pool.gd` | `DungeonEncounterPool` | Scans encounter folders and filters weighted encounters by floor layer. |
| `res://core/dungeon/encounters/dungeon_encounter_resolver.gd` | `DungeonEncounterResolver` | Resolves encounter IDs, scenes, and choices. |
| `res://core/dungeon/encounters/dungeon_combat_encounter_data.gd` | `DungeonCombatEncounterData` | Authored Fight/Boss combat encounter metadata and enemy slot data. |
| `res://core/dungeon/encounters/dungeon_combat_encounter_pool.gd` | `DungeonCombatEncounterPool` | Scans and filters weighted combat encounters for seeded Fight/Boss descriptor assignment. |
| `res://scenes/dungeon/dungeon_grid_view.gd` | `DungeonGridView` | Draws the dungeon map grid behind generated nodes. |
| `res://scenes/dungeon/dungeon_map_input_connector.gd` | `DungeonMapInputConnector` | Applies map navigation keybinds to dungeon zooming and panning. |
| `res://scenes/dungeon/dungeon_map_pawn_view.gd` | `DungeonMapPawnView` | Draws one display-only marker for a run-owned dungeon pawn. |
| `res://scenes/dungeon/dungeon_node_view.gd` | `DungeonNodeView` | Texture button view for dungeon nodes and selection tooltips. |
| `res://scenes/dungeon/encounters/dungeon_choice_encounter.gd` | `DungeonChoiceEncounter` | Generic encounter choice scene that emits selected encounter results. |

## UI

| Script | Class | Purpose |
| --- | --- | --- |
| `res://scenes/combat/ui/action_bar.gd` | `BattleActionBar` | Binds manually positioned hotbar buttons to configurable slot contents. |
| `res://scenes/combat/ui/action_queue_panel.gd` | `ActionQueuePanel` | Renders pending and resolved combat actions. |
| `res://scenes/combat/ui/battle_hud.gd` | `BattleHUD` | Coordinates the combat timeline, hotbar action buttons, targeting gate, hotbar resource bars, player status bar, hover info panel, and time controls. |
| `res://scenes/combat/ui/combatant_display.gd` | `CombatantDisplay` | Reusable battle display for one combatant's visual, HP, statuses, hover name panel, and target-selection highlight. |
| `res://scenes/combat/ui/hover_info_button.gd` | `HoverInfoButton` | Button with authored hover info metadata for the fixed info panel. |
| `res://scenes/combat/ui/hover_info_panel.gd` | `HoverInfoPanel` | Fixed info panel that renders hover metadata from registered controls. |
| `res://scenes/combat/ui/hotbar_slot_button.gd` | `HotbarSlotButton` | Button for one configurable combat hotbar slot. |
| `res://scenes/combat/ui/status_icon_view.gd` | `StatusIconView` | Control view that previews and renders a status icon from the shared status atlas. |
| `res://scenes/ui/common/number_font.gd` | `NumberFont` | Applies and draws shared-font numeric spans. |
| `res://scenes/ui/common/resource_bar.gd` | None | Custom resource meter control with optional segmented overlay fills. |
| `res://scenes/ui/common/time_progress_bar.gd` | `TimeProgressBar` | Draws run timer fill inside the timer fill node's bounds. |
| `res://scenes/ui/global_hud/global_hud.gd` | None | Persistent HUD layer for timer, currencies, and selected character stats. |
| `res://scenes/ui/main_menu/main_menu.gd` | None | Main menu routing and button handling. |
| `res://scenes/ui/run_summary/run_summary.gd` | None | Final run stats and memory export UI. |
| `res://scenes/ui/waiting_room/waiting_room.gd` | None | Character/difficulty selection before dungeon run. |

## See also

- [[Key runtime APIs]]
- [[Resource inventory]]
- [[Signals and events]]
- [[Documentation workflow]]
