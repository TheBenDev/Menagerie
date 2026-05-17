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
| `start_combat(node_id, node_type, enemy_profile_path, is_boss, charge_travel_time := true, combat_encounter_id := &"", combat_encounter_profile_path := "")` | method | Stores routed combat encounter metadata and routes to battle. Direct route calls can charge node travel time; movement-arrival calls pass `false` because the node step already charged time. |
| `complete_combat(result)` | method | Stores pending result, routes to dungeon. |
| `advance_run_time(seconds)` | method | Decrements remaining run time and handles timeout. |
| `get_dungeon_encounter(encounter_id)` | method | Resolves an authored dungeon encounter resource by ID. |
| `get_dungeon_encounter_scene(encounter_id)` | method | Resolves the presentation scene for an encounter ID. |
| `get_dungeon_combat_encounter(encounter_id)` | method | Resolves an authored Fight/Boss combat encounter resource by ID. |
| `get_dungeon_abilities(slot_count := 3)` | method | Returns class-agnostic dungeon hotbar abilities from the default pool. |
| `apply_dungeon_encounter_result(encounter_id, result)` | method | Applies a completed encounter choice result to `RunData`. |
| `apply_run_player_state_to_combatant(combatant)` | method | Copies effective run stats onto the player combatant before battle. |
| `get_run_player_hp_snapshot()` | method | Returns persistent run HP as `{current, max}`. |
| `get_effective_player_stats()` | method | Returns effective run stats after permanent and timed modifiers. |
| `get_selected_character_profile_path()` | method | Returns the selected character profile path used to seed run-owned `CombatantState`. |
| `go_to_scene(scene_ref)` | method | Main route endpoint. |
| `scene_path_for(scene_ref)` | method | Use to check route resolution without changing scene. |

## RunData party state

| Surface | Type | Notes |
| --- | --- | --- |
| `player_party_state` | `PlayerPartyState` or `null` | Run-owned player roster. Phase 1 creates one active Warrior member. |
| `PlayerPartyState.members` | `Dictionary` | Maps party member IDs to `PlayerPartyMemberState` objects. |
| `PlayerPartyState.active_member_ids` | `Array[String]` | Ordered active roster IDs for future pawn/combat participation. |
| `PlayerPartyState.leader_member_id`, `selected_member_id` | `String` | Current leader and selected party member IDs. |
| `PlayerPartyMemberState.control_mode` | `int` | Uses `PartyControlMode`: `LocalPlayer`, `AutoPilot`, `RemotePlayer`, or `Inactive`. |
| `PlayerPartyMemberState.map_pawn_id` | `String` | Links an active party member to its run-owned dungeon pawn. |
| `PlayerPartyMemberState.combatant_state` | `CombatantState` | Reusable persistent combat data for the party member. |
| `CombatantState.current_hp`, `max_hp` | `int` | Intended persistent HP model. Existing `RunData.player_*` fields mirror these values in Phase 1. |
| `CombatantState.stats` | `Dictionary` | Base stat map keyed by `STR`, `DEX`, `INT`, and `VIT`. |
| `CombatantState.runtime_modifiers` | `Array[Dictionary]` | Mirrored run stat modifiers used by `get_effective_stat()`. |

## RunData dungeon state

| Surface | Type | Notes |
| --- | --- | --- |
| `dungeon_map_pawns` | `Dictionary` | Maps pawn IDs to `DungeonMapPawnState` objects. Phase 2 creates one Warrior pawn. |
| `active_dungeon_pawn_ids` | `Array[String]` | Ordered active pawn IDs for later synchronized travel. |
| `revealed_dungeon_node_ids` | `Array[int]` | Nodes visible on the dungeon map. New runs reveal Haven and its descriptor-connected neighbors. |
| `visited_dungeon_node_ids` | `Array[int]` | Nodes physically entered by a dungeon pawn. |
| `resolved_dungeon_node_ids` | `Array[int]` | Nodes whose current event/effect is complete. |
| `dungeon_seed` | `String` | Stored seed used to reproduce the generated dungeon map and gameplay RNG stream. |
| `dungeon_floor_layer` | `int` | Current floor layer; `1` until multi-floor progression exists. |
| `dungeon_node_descriptors` | `Array` | Stored generated map descriptors for the active run. Fight/Boss descriptors carry `combat_encounter_id`, `combat_encounter_profile_path`, and legacy `enemy` profile path data. |
| `current_dungeon_node_id` | `int` | Compatibility mirror of the selected dungeon pawn's current node. |
| `player_current_hp`, `player_max_hp` | `int` | Compatibility mirrors for Warrior `CombatantState` HP, still used by existing HUD and combat setup APIs. |
| `run_stat_modifiers` | `Array[Dictionary]` | Permanent and run-time-limited stat modifiers from encounter choices, mirrored into Warrior `CombatantState`. |
| `initialize_dungeon_map_state(start_node_id := 0)` | method | Creates active member pawns, marks Haven revealed/visited, and reveals descriptor-connected neighbors. Haven does not start resolved. |
| `get_selected_dungeon_map_pawn()` | method | Returns the selected or leader pawn. |
| `get_current_dungeon_node_id()` | method | Returns the selected pawn's current node, falling back to the legacy mirror. |
| `complete_dungeon_node(node_id, pawn_id := "")` | method | Marks a node visited/resolved, reveals connected neighbors, syncs explicit or event-locked participant pawns, and unlocks pawns assigned to that event node. Falls back to the selected pawn only when no participant lock exists. |
| `mark_dungeon_node_visited(node_id, pawn_id := "")` | method | Adds a visited node ID on entry, reveals that node and descriptor-connected neighbors, and syncs the entering pawn when provided. |
| `mark_dungeon_node_resolved(node_id)` | method | Adds a resolved node ID. |
| `reveal_connected_dungeon_nodes(node_id)` | method | Reveals neighboring node IDs using descriptor connections, with linear fallback for older descriptors. |
| `is_dungeon_node_visited(node_id)` | method | Checks whether a pawn has entered a node. |
| `is_dungeon_node_revealed(node_id)` | method | Checks whether a node is visible on the map. |
| `is_dungeon_node_resolved(node_id)` | method | Checks whether a node's event/effect is complete. |
| `get_visited_dungeon_node_ids()` | method | Returns a duplicate of visited node IDs for reveal calculations. |
| `get_revealed_dungeon_node_ids()` | method | Returns a duplicate of revealed node IDs. |
| `get_resolved_dungeon_node_ids()` | method | Returns a duplicate of resolved node IDs. |
| `get_occupied_dungeon_node_ids()` | method | Derives occupied node IDs from current pawn positions. |
| `get_last_visited_dungeon_node_id()` | method | Compatibility helper that returns the selected pawn/current node first, then the latest visited node. |
| `request_selected_dungeon_pawn_travel(destination_node_id)` | method | Requests a path-based travel order for the selected pawn. Accepted local-leader orders can also create `AutoPilot` follow orders. |
| `request_dungeon_pawn_travel(pawn_id, destination_node_id)` | method | Validates pathing and stores a travel order or pending replacement. If the pawn belongs to the local leader, active `AutoPilot` pawns attempt to follow the same destination. |
| `can_request_selected_dungeon_pawn_travel(destination_node_id)` | method | Checks whether the selected pawn can path to a destination without mutating travel state. |
| `get_dungeon_pawn_travel_path(pawn_id, destination_node_id)` | method | Returns the allowed path for a pawn using current descriptor connections and revealed/visited/resolved node IDs. |
| `get_allowed_dungeon_path_node_ids()` | method | Returns the current pathable node set derived from revealed, visited, resolved, and active pawn current positions. |
| `get_dungeon_connection_graph()` | method | Returns a descriptor-derived connection graph for pathfinding. |
| `get_event_locked_dungeon_pawn_ids(node_id)` | method | Returns pawn IDs currently locked as participants in an unresolved event at that node. |
| `unlock_dungeon_pawns_for_event_node(node_id)` | method | Clears event lock state for pawns whose active event node was resolved. |
| `apply_encounter_choice(choice_data)` | method | Applies an inline encounter choice dictionary, currently damage and stat modifiers. |
| `get_effective_stat(stat_id)` | method | Returns a stat after active run modifiers. |

## DungeonMapPawnState

| Surface | Type | Notes |
| --- | --- | --- |
| `pawn_id`, `party_member_id`, `combatant_id`, `owner_player_id` | `String` | Identity links for party, combat, and future co-op ownership. |
| `control_mode` | `int` | Mirrors the owning party member's `PartyControlMode`. |
| `current_node_id` | `int` | Authoritative dungeon map position for this pawn. |
| `travel_origin_node_id`, `destination_node_id`, `travel_path`, `travel_path_index`, `pending_destination_node_id` | mixed | Travel-order state used by path-based dungeon movement. |
| `step_game_cost_seconds`, `visual_steps_per_second` | `float` | Per-order tuning values that keep `RunData.NODE_TRAVEL_TIME` separate from visual playback speed. |
| `cancel_requested` | `bool` | Defers cancellation until the movement coordinator finishes the current node step. |
| `travel_state` | `int` | One of `Idle`, `Traveling`, `InEvent`, or `Inactive`. |
| `is_locked_by_event`, `active_event_node_id` | mixed | Event-lock state used when an unresolved Fight, Boss, or Encounter arrival starts an active event. |
| `set_travel_order(destination_node_id, travel_path, step_cost, visual_speed)` | method | Assigns a validated path order without advancing the pawn. |
| `request_destination_replacement(destination_node_id)` | method | Queues a new destination to apply after the current node step. |
| `request_cancel_after_current_step()` | method | Marks the active order for cancellation after the current step. |
| `has_active_travel_order()` | method | Checks whether this pawn has an active path order. |
| `next_path_node_id()` | method | Returns the next node in the active path, or `-1` if none is available. |
| `lock_for_event(node_id)` | method | Clears travel and marks this pawn as an active participant in the unresolved event at `node_id`. |
| `unlock_event()` | method | Clears event-lock state after that event node resolves. |

Accepted leader travel results may include `autopilot_follow_results`, an array of dictionaries with `pawn_id`, `accepted`, `reason`, `path`, and `queued_replacement` for each active `AutoPilot` follower that attempted to follow.

## DungeonMovementCoordinator

| Surface | Type | Notes |
| --- | --- | --- |
| `has_active_travel_orders(run_data)` | static method | Checks whether any active pawn has a travel order with a next node step. |
| `advance_one_step(run_data, interrupt_node_ids := [])` | static method | Advances all active traveling pawns one node step and returns moved/pause/replacement/cancel/interruption details. |
| `RESULT_PAUSE_REQUESTED`, `RESULT_PAUSE_REASONS` | constants | Result keys used by `DungeonController` to decide whether the shared movement loop should stop. |

## DungeonMapPawnView

| Surface | Type | Notes |
| --- | --- | --- |
| `configure(pawn, node_data, cell_size)` | method | Initializes a visual marker from a pawn and the node containing it. |
| `apply_pawn_state(pawn, node_data, cell_size)` | method | Repositions and redraws the marker from authoritative run-owned pawn state. |
| `marker_center_for_node(node_data, cell_size)` | static method | Returns the marker center in map-content coordinates, centered on `1x1` nodes and top-left anchored on larger nodes. |
| `marker_color`, `outline_color`, `marker_diameter` | exports | Tune the placeholder circle marker without changing gameplay state. |

## Dungeon helpers

| Surface | Type | Notes |
| --- | --- | --- |
| `DungeonNodeEventHelper.build_node_event(node)` | static method | Builds the shared dictionary payload for dungeon node visit events. |
| `DungeonPathfinder.connection_graph_from_descriptors(descriptors, use_linear_fallback := true)` | static method | Builds a symmetric connection graph from dungeon descriptors, with linear fallback for older descriptor sets. |
| `DungeonPathfinder.find_path(start_node_id, destination_node_id, allowed_node_ids, connection_graph)` | static method | Returns an ordered allowed route from start to destination, or an empty array when the destination is hidden/disallowed/unreachable. |
| `DungeonFloorGenerator.generate_floor(seed, layer, difficulty, config, encounter_pool, combat_encounter_pool)` | static method | Seeds global RNG from `seed`, then returns deterministic flat descriptor arrays with optional `connections`, choice encounter IDs, and combat encounter IDs. |
| `DungeonFloorGenerator.generate_floor_from_global_rng(layer, difficulty, config, encounter_pool, combat_encounter_pool)` | static method | Returns descriptors by consuming the current global gameplay RNG stream, including seeded Fight/Boss combat encounter assignments. |
| `DungeonFloorGenerator.validate_descriptors(descriptors, grid_size := Vector2i.ZERO)` | static method | Checks bounds, overlaps, graph reachability, and symmetric connections. |
| `DungeonEncounterResolver.encounter_for_id(pool, encounter_id)` | static method | Resolves encounter data from a pool. |
| `DungeonEncounterResolver.scene_for_encounter(encounter_data)` | static method | Returns the encounter presentation scene. |
| `DungeonEncounterResolver.choice_for_index(encounter_data, choice_index)` | static method | Resolves an inline choice dictionary by emitted choice index. |
| `DungeonEncounterPoolHelper.available_for_floor(encounters, floor_layer)` | static method | Shared filter used by encounter and combat encounter pools. |
| `DungeonEncounterPoolHelper.pick_weighted(encounters)` | static method | Shared weighted-pick helper for already-filtered encounter resources. |
| `DungeonCombatEncounterPool.pick_for_floor(floor_layer)` | method | Uses seeded RNG to choose a weighted Fight/Boss combat encounter valid for the floor. |
| `DungeonCombatEncounterPool.profile_path_for_id(encounter_id)` | method | Returns the resource path for a loaded combat encounter ID. |
| `DungeonCombatEncounterData.enemy_slots` | exported array | Enemy slot dictionaries use `combatant_profile_path` and `position_id`; `BattleScene` currently consumes the first slot for the active enemy profile and display placement. |
| `DungeonCombatEncounterData.primary_enemy_profile_path()` | method | Returns the first enemy slot's combatant profile path for the current one-enemy battle scene bridge. |
| `KeybindsHelper.process_map_navigation_event(event, is_panning)` | static method | Converts wheel and middle-mouse events into zoom/pan action dictionaries. |

## Shared services

| Surface | Type | Notes |
| --- | --- | --- |
| `RewardService.calculate_combat_rewards(profile, difficulty_profile, is_boss)` | static method | Calculates non-negative memory/gold rewards from a combatant reward profile and selected difficulty. |
| `RewardService.normalize_reward_result(reward_result)` | static method | Converts reward-shaped dictionaries or objects into `{memories_awarded, gold_awarded}`. |
| `PlayerRunStateService.effective_player_stats(run_data, fallback_profile)` | static method | Returns current run stats, or profile base stats when no run exists. |
| `PlayerRunStateService.hp_snapshot(run_data)` | static method | Returns persistent player HP as `{current, max}` with an empty-state fallback. |
| `SceneRouteService.scene_path_for(scene_ref)` | static method | Normalizes route references to `res://scenes/... .tscn` paths. |
| `SceneRouteService.music_id_for_scene_path(scene_path)` | static method | Resolves scene paths to authored music track IDs. |
| `ValueReader.resource_float(resource, field_name, default_value)` | static method | Reads numeric Resource fields without duplicating null/type checks. |

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
| `player_group`, `enemy_group` | `CombatantGroup`-like or `null` | Temporary combat-side groups used by the battle loop. Current gameplay configures one combatant per side. |
| `player`, `enemy` | `Combatant` or `null` | Primary convenience references preserved for current HUD/display/audio code. They mirror the first living combatant in each group when possible. |
| `difficulty_profile` | exported field | Optional; falls back to `normal.tres`. |
| `current_time` | field | Snapped combat time in seconds. |
| `waiting_for_player_input` | field | Controls HUD action availability. |
| `action_queue` | `Array[QueuedAction]` | Timeline queue consumed by HUD and audio bridge. |
| `configure_combatant_groups(player_combatants, enemy_combatants)` | method | Sets the player and enemy combatant groups and refreshes the primary convenience references. |
| `get_player_combatants()`, `get_enemy_combatants()` | method | Returns duplicates of the configured side combatant arrays. |
| `get_living_player_combatants()`, `get_living_enemy_combatants()` | method | Returns living combatants for each side. |
| `is_player_group_defeated()`, `is_enemy_group_defeated()` | method | Checks whether an entire side has no living combatants. |
| `start_battle()` | method | Resets state, applies difficulty, emits initial signals. |
| `player_choose_action(action, explicit_targets := [])` | method | Queues the primary player action, optionally using one or more explicit targets for later targeting flows. |
| `cycle_time_scale()` | method | Rotates through `[0.5, 1.0, 2.0, 4.0]`. |
| `set_paused(new_is_paused)` | method | Updates pause state and emits `pause_changed`. |
| `advance_until_input_needed()` | method | Main async time loop. |

## CombatantGroup

| Surface | Type | Notes |
| --- | --- | --- |
| `group_id` | `String` | Side identifier such as `player` or `enemy`. |
| `combatants` | `Array[Combatant]` | Unique combatants on that temporary battle side. |
| `set_combatants(combatants)` | method | Replaces the group with valid unique combatants. |
| `add_combatant(combatant)`, `remove_combatant(combatant)` | method | Mutates the temporary group membership. |
| `get_living_combatants()`, `get_dead_combatants()` | method | Returns side members split by HP state. |
| `has_living_combatants()` | method | Returns true if at least one group member has HP remaining. |
| `contains_combatant(combatant_id)` | method | Looks up a combatant by explicit ID when present, then node name, then instance ID. |
| `get_first_combatant()`, `get_first_living_combatant()` | method | Convenience helpers used to preserve current primary 1v1 references. |

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
