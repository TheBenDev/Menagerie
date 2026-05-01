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
3. Add effects directly before the move that uses them.
4. Set AI role metadata so `EnemyBrain` can score moves in context.

## Create enemy profile

1. Create a `CombatantProfile` resource.
2. Set display fields, stats, timeline marker data, and health bar config.
3. Link `enemy_ai_profile` to the enemy AI resource.
4. Link `reward_profile` to the reward resource.
5. Add hit/block/death SFX IDs if available.

## Add to dungeon

1. Open `res://scenes/dungeon/dungeon_controller.gd`.
2. Add or update a node descriptor in `DEFAULT_NODE_DESCRIPTORS`.
3. Set its `enemy` value to the new enemy profile path.
4. Set `is_boss` for boss encounters.
5. Open `res://scenes/dungeon/DungeonMap.tscn` through Godot to verify the generated node placement.

## Optional battle visual

If the enemy needs unique art, follow [[Adding a battle visual]] and then wire the scene into the battle HUD layout.

## Validate behavior

- Start a run and select a node with the new enemy profile.
- Confirm `BattleScene` loads the profile from `GameManager.get_current_encounter()`.
- Confirm the enemy has actions after `EnemyCombatant.apply_profile()`.
- Confirm rewards are granted on victory.
- Run the headless load command after changing resources/scenes.

## See also

- [[Adding a combat action]]
- [[Adding a status or effect]]
- [[Adding audio]]
- [[Battle visuals]]
- [[Resource inventory]]
