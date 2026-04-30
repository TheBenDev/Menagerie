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
| `start_new_run(character, difficulty)` | method | Creates and stores fresh `RunData`. |
| `start_combat(node_id, node_type, enemy_profile_path, is_boss)` | method | Stores encounter, charges travel time, routes to battle. |
| `complete_combat(result)` | method | Stores pending result, routes to dungeon. |
| `advance_run_time(seconds)` | method | Decrements remaining run time and handles timeout. |
| `go_to_scene(scene_ref)` | method | Main route endpoint. |
| `scene_path_for(scene_ref)` | method | Use to check route resolution without changing scene. |

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
| `effects` | `Array[ActionEffect]` | Ordered effect resources. |
| `start_sfx_id` | `StringName` | Played by `CombatAudioBridge` when action starts. |
| `resolve_sfx_id` | `StringName` | Played by `CombatAudioBridge` when action resolves. |
| `hp_cost`, `mana_cost` | `int` | HP cost is applied by `ActionResolver`; mana is reserved. |
| `target_enemy` | `bool` | Player action targeting side. |

## ActionEffect

| Field/method | Type | Notes |
| --- | --- | --- |
| `effect_id` | `StringName` | Namespaced behavior ID. |
| `amount` | `int` | Generic amount used by block, rage, strength, etc. |
| `base_damage` | `int` | Damage base value. |
| `scaling_stat` | `String` | One of `STR`, `DEX`, `INT`, `VIT`. |
| `scaling_multiplier` | `float` | Multiplied by source stat, floored, added to base. |
| `status_id` | `StringName` | Status ID or path for `status.apply`. |
| `duration_override_seconds` | `float` | Optional status duration override. |
| `apply(source, targets, action)` | method | Dispatches to `CombatEffectLibrary`. |
| `estimate_power(source, targets, action)` | method | Used by enemy AI scoring. |

## CombatEffectLibrary

| Surface | Type | Notes |
| --- | --- | --- |
| `apply_effect(effect, source, targets, action)` | static method | Dispatches effect behavior by canonical effect ID. |
| `estimate_power(effect, source, targets, action)` | static method | Estimates damage/block/strength value for AI. |
| `status_path_for_id(status_id)` | static method | Resolves `status.foo` and `foo` to `res://data/statuses/foo.tres`. |
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
