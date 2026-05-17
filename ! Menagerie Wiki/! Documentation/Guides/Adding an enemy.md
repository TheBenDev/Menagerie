---
title: Adding an enemy
page-type: guide
status: draft
---

Use this guide to add a new enemy profile, AI profile, rewards, and optional battle visual.

## Create the data folder

Create a folder under `res://scenes/combatants/enemies/<enemy_name>`.

Use existing Training Ghoul resources as the pattern:

- `res://scenes/combatants/enemies/training_ghoul/training_ghoul_profile.tres`
- `res://scenes/combatants/enemies/training_ghoul/training_ghoul_ai.tres`
- `res://scenes/combatants/enemies/training_ghoul/training_ghoul_visual_state_machine_config.tres`

## Create rewards

1. Create or reuse a `RewardProfile` resource.
2. Set `base_memories`, `base_gold`, and `boss_multiplier`.
3. Link it from the enemy `CombatantProfile.reward_profile`.

## Create enemy AI

1. Create an `EnemyAIProfile` resource.
2. Add `EnemyMoveData` subresources for each move.
3. Add inline `effect_data` dictionaries to each move.
4. Set AI role metadata so `EnemyBrain` can score moves in context.

## Create enemy profile

1. Create a `CombatantProfile` resource.
2. Set display fields, stats, timeline marker data, and health bar config.
3. Link `enemy_ai_profile` to the enemy AI resource.
4. Link `reward_profile` to the reward resource.
5. Add hit/block/death SFX IDs if available.

## Add to dungeon

1. Create a `DungeonCombatEncounterData` resource under `res://core/dungeon/encounters/combat/`.
2. Set `id`, display fields, floor validity, and `weight`.
3. Add an `enemy_slots` dictionary with `combatant_profile_path` pointing at the enemy profile and `position_id` such as `EnemySlot1`.
4. Confirm `res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres` scans that folder.
5. Open `res://scenes/dungeon/DungeonMap.tscn` through Godot to verify generated Fight/Boss nodes receive a stable `combat_encounter_id` and compatibility enemy profile path.

## Optional battle visual

If the enemy needs unique art, follow [[Adding a battle visual]] and then assign the scene to the enemy `CombatantProfile.battle_visual_scene`.

## Validate behavior

- Start a run and select a node with the new enemy profile.
- Confirm `BattleScene` loads the combat encounter from `GameManager.get_current_encounter()` and uses the first enemy slot's profile in the current one-enemy battle scene.
- Confirm the enemy has actions after `EnemyCombatant.apply_profile()`.
- Confirm rewards are granted on victory.
- Run the headless load command after changing resources/scenes.

## See also

- [[Adding a combat action]]
- [[Adding a status or effect]]
- [[Adding audio]]
- [[Battle visuals]]
- [[Resource inventory]]
