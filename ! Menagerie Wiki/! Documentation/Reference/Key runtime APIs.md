---
title: Key runtime APIs
page-type: reference
status: draft
---

This page summarizes the most important runtime APIs new developers usually need first.

## GameManager

| Surface | Type | Notes |
| --- | --- | --- |
| `current_run_data` | `RunData` or `null` | Active run state. May be null outside a run. |
| `start_new_run(character, difficulty, dungeon_seed := "", dungeon_floor_layer := 1)` | method | Creates and stores fresh `RunData`; blank seed resolves to an auto-generated replay seed. |
| `start_combat(node_id, node_type, enemy_profile_path, is_boss)` | method | Stores encounter, charges travel time, routes to battle. |
| `complete_combat(result)` | method | Stores pending result, routes to dungeon. |
| `advance_run_time(seconds)` | method | Decrements remaining run time and handles timeout. |
| `get_dungeon_encounter(encounter_id)` | method | Resolves an authored dungeon encounter resource by ID. |
| `get_dungeon_encounter_scene(encounter_id)` | method | Resolves the presentation scene for an encounter ID. |
| `apply_dungeon_encounter_result(encounter_id, result)` | method | Applies a completed encounter choice result to `RunData`. |
| `apply_run_player_state_to_combatant(combatant)` | method | Copies effective run stats onto the player combatant before battle. |
| `get_run_player_hp_snapshot()` | method | Returns persistent run HP as `{current, max}`. |
| `get_effective_player_stats()` | method | Returns effective run stats after permanent and timed modifiers. |
| `go_to_scene(scene_ref)` | method | Main route endpoint. |
| `scene_path_for(scene_ref)` | method | Use to check route resolution without changing scene. |

## RunData dungeon state

| Surface | Type | Notes |
| --- | --- | --- |
| `visited_dungeon_node_ids` | `Array[int]` | Source of truth for visited dungeon map nodes. |
| `dungeon_seed` | `String` | Stored seed used to reproduce the generated dungeon map and gameplay RNG stream. |
| `dungeon_floor_layer` | `int` | Current floor layer; `1` until multi-floor progression exists. |
| `dungeon_node_descriptors` | `Array` | Stored generated map descriptors for the active run. |
| `current_dungeon_node_id` | `int` | Last visited node id for branching-map current-location display. |
| `player_current_hp`, `player_max_hp` | `int` | Persistent player HP carried between fights and affected by encounter damage. |
| `run_stat_modifiers` | `Array[Dictionary]` | Permanent and run-time-limited stat modifiers from encounter choices. |
| `mark_dungeon_node_visited(node_id)` | method | Adds a visited node ID and advances `current_node_index`. |
| `is_dungeon_node_visited(node_id)` | method | Checks whether a node was completed. |
| `get_visited_dungeon_node_ids()` | method | Returns a duplicate of visited node IDs for reveal calculations. |
| `get_last_visited_dungeon_node_id()` | method | Returns the latest visited node ID, or `-1` before Haven is completed. |
| `apply_encounter_choice(choice_data)` | method | Applies an inline encounter choice dictionary, currently damage and stat modifiers. |
| `get_effective_stat(stat_id)` | method | Returns a stat after active run modifiers. |

## Dungeon helpers

| Surface | Type | Notes |
| --- | --- | --- |
| `DungeonNodeEventHelper.build_node_event(node)` | static method | Builds the shared dictionary payload for dungeon node visit events. |
| `DungeonNodeEventHelper.process_node_event(node, game_manager, sound_manager)` | static method | Handles currently-routed node types and reports whether completion is deferred. |
| `DungeonFloorGenerator.generate_floor(seed, layer, difficulty, config, encounter_pool)` | static method | Seeds global RNG from `seed`, then returns deterministic flat descriptor arrays with optional `connections` and encounter IDs. |
| `DungeonFloorGenerator.generate_floor_from_global_rng(layer, difficulty, config, encounter_pool)` | static method | Returns descriptors by consuming the current global gameplay RNG stream. |
| `DungeonFloorGenerator.validate_descriptors(descriptors, grid_size := Vector2i.ZERO)` | static method | Checks bounds, overlaps, graph reachability, and symmetric connections. |
| `DungeonEncounterResolver.encounter_for_id(pool, encounter_id)` | static method | Resolves encounter data from a pool. |
| `DungeonEncounterResolver.scene_for_encounter(encounter_data)` | static method | Returns the encounter presentation scene. |
| `DungeonEncounterResolver.choice_for_index(encounter_data, choice_index)` | static method | Resolves an inline choice dictionary by emitted choice index. |
| `KeybindsHelper.process_map_navigation_event(event, is_panning)` | static method | Converts wheel and middle-mouse events into zoom/pan action dictionaries. |

## SoundManager

| Surface | Type | Notes |
| --- | --- | --- |
| `play_sfx(id, options := {})` | method | Use for gameplay SFX. |
| `play_ui(id, options := {})` | method | Use for UI sounds; buttons already auto-click. |
| `play_music(id, fade_seconds := -1.0, restart := false)` | method | Starts or crossfades music. |
| `set_music_state(state_id, intensity := 0.0)` | method | Requests an adaptive music state. |
| `set_bus_volume(bus_name, linear_value)` | method | Volume endpoint for settings UI. |
| `get_music_debug_state()` | method | Use for diagnosing music and stream registration. |

## BattleController

| Surface | Type | Notes |
| --- | --- | --- |
| `player` | field | Assigned by `BattleScene` before `start_battle()`. |
| `enemy` | field | Assigned by `BattleScene` before `start_battle()`. |
| `difficulty_profile` | exported field | Optional; falls back to `normal.tres`. |
| `current_time` | field | Snapped combat time in seconds. |
| `waiting_for_player_input` | field | Controls HUD action availability. |
| `action_queue` | `Array[QueuedAction]` | Timeline queue consumed by HUD and audio bridge. |
| `start_battle()` | method | Resets state, applies difficulty, emits initial signals. |
| `player_choose_action(action)` | method | Queues player action, triggers enemy choice, advances time. |
| `cycle_time_scale()` | method | Rotates through `[0.5, 1.0, 2.0, 4.0]`. |
| `set_paused(new_is_paused)` | method | Updates pause state and emits `pause_changed`. |
| `advance_until_input_needed()` | method | Main async time loop. |

## Combatant

| Surface | Type | Notes |
| --- | --- | --- |
| `profile` | exported field | `CombatantProfile`; copied by `apply_profile()`. |
| `actions` | `Array[CombatActionData]` | Available actions copied from profile moveset. |
| `statuses` | `Dictionary` | Runtime status map keyed by status ID. |
| `apply_profile()` | method | Copies identity, stats, and actions from profile. |
| `reset_runtime_state()` | method | Resets HP, block, statuses, multipliers, and pending action. |
| `start_action(action, targets, current_time)` | method | Stores pending action and finish time. |
| `resolve_pending_action()` | method | Applies pending action through `ActionResolver`. |
| `take_damage(packet)` | method | Applies block, HP loss, damage callbacks, and death signal. |
| `add_status(status_data, duration_override_seconds := -1.0)` | method | Adds or refreshes a timed status. |
| `get_resource_snapshot(resource_id)` | method | Feeds UI bars; base supports `health`. |

## CombatActionData

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `String` | Stable action ID. |
| `display_name` | `String` | UI label and battle log text. |
| `time_cost` | `float` | Base action duration before multipliers. |
| `effect_data` | `Array[Dictionary]` | Ordered effect calls. Each dictionary uses `id` plus fields for that effect. |
| `start_sfx_id` | `StringName` | Played by `CombatAudioBridge` when action starts. |
| `resolve_sfx_id` | `StringName` | Played by `CombatAudioBridge` when action resolves. |
| `hp_cost`, `mana_cost` | `int` | HP cost is applied by `ActionResolver`; mana is reserved. |
| `target_enemy` | `bool` | Player action targeting side. |

## Effect Data

| Key | Type | Notes |
| --- | --- | --- |
| `id` | `StringName` | Namespaced behavior ID. |
| `amount` | `int` | Generic amount used by block, rage, strength, etc. |
| `base_damage` | `int` | Damage base value. |
| `scaling_stat` | `String` | One of `STR`, `DEX`, `INT`, `VIT`. |
| `scaling_multiplier` | `float` | Multiplied by source stat, floored, added to base. |
| `status_id` | `StringName` | Status ID or path for `status.apply`. |
| `duration_override_seconds` | `float` | Optional status duration override. |

## CombatEffectLibrary

| Surface | Type | Notes |
| --- | --- | --- |
| `apply_effect(effect_data, source, targets, action)` | static method | Dispatches effect behavior by canonical effect ID. |
| `estimate_power(effect_data, source, targets, action)` | static method | Estimates damage/block/strength value for AI. |
| `status_path_for_id(status_id)` | static method | Resolves `status.foo` and `foo` to `res://core/statuses/foo.tres`. |
| `combat.damage` | effect ID | Deals damage. |
| `combat.block` | effect ID | Grants source block. |
| `status.apply` | effect ID | Applies status resource to targets. |
| `resource.rage.gain` | effect ID | Calls `source.gain_rage()`. |
| `stat.strength.add` | effect ID | Adjusts strength on targets or source. |

## See also

- [[Autoload APIs]]
- [[Combat flow]]
- [[Data and resource model]]
- [[Adding a combat action]]
- [[Adding a status or effect]]
