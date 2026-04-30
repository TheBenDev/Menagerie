---
title: Asset inventory
page-type: reference
status: draft
---

This inventory covers source asset groups used by scenes, UI, battle visuals, and audio.

## Visual assets

| Group | Paths | Use |
| --- | --- | --- |
| Backgrounds | `res://assets/Backgrounds/Dungeon background cartoon 2d *.jpg` | Dungeon/background art candidates. |
| Warrior sprites | `res://assets/characters/Warrior/*.png`, `warrior_idle_frames.tres` | Warrior battle visual frames. |
| Training Ghoul sprites | `res://assets/enemies/training_ghoul/*.png`, `training_ghoul_visual_frames.tres` | Training Ghoul battle visual frames. |
| Fantasy UI pack | `res://assets/FantasyUIfree/*` | UI frame and bar source art. |
| Fonts | `res://assets/Gotfridus_Font_0_5/*` | Gotfridus font files and license. |
| Main menu UI | `res://assets/ui/Main Menu/*` | Main menu background and texture buttons. |
| Global UI | `res://assets/ui/global/textured_background.png`, `TimeProgressBar.png`, `TitleIcon.png`, `AppIcon.png` | Shared UI art and app icon. |
| Theme | `res://assets/ui/menagerie_theme.tres` | Project UI theme. |

## Audio assets

| Group | Paths | Runtime IDs |
| --- | --- | --- |
| Base music | `res://sounds/music/bgtheme.wav` | `music.bgtheme` |
| Dungeon music | `res://sounds/music/Dungeon/*.wav` | `music.dungeon.*` |
| Ambience stems | `res://sounds/music/Stems/Ambience/*.wav` | `music.stems.ambience.*` |
| Boss SFX | `res://sounds/sfx/Boss/BossStartFight.wav` | `sfx.boss.boss_start_fight` |
| Enemy SFX | `res://sounds/sfx/Enemy/Jockey/diddy jocky.wav` | `sfx.enemy.jockey.diddy_jocky` |
| Global SFX | `res://sounds/sfx/Global/Death/RunEndsLoop.wav` | `sfx.global.death.run_ends_loop` |
| UI sounds | `res://sounds/ui/Button/Click.wav`, `res://sounds/ui/Notification/SkillTreePoint.wav` | `ui.button.click`, `ui.notification.skill_tree_point` |

## Files not normally documented

- `.import` files are Godot import metadata.
- `.uid` files are Godot-generated resource IDs.
- Scene `.tmp` files are editor temp files.

## See also

- [[Audio IDs]]
- [[Battle visuals]]
- [[Adding audio]]
- [[Adding a battle visual]]
