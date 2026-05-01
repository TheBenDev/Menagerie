---
title: Asset inventory
page-type: reference
status: draft
---

This inventory covers source asset groups used by scenes, UI, battle visuals, and audio.

## Visual assets

| Group | Paths | Use |
| --- | --- | --- |
| Warrior sprites | `res://scenes/combatants/characters/warrior/textures/*` | Warrior battle visual frames. |
| Training Ghoul sprites | `res://scenes/combatants/enemies/training_ghoul/textures/*` | Training Ghoul battle visual frames. |
| Fonts | `res://assets/fonts/gotfridus_font_0_5/*` | Gotfridus font files and license. |
| Main menu UI | `res://assets/ui/main_menu/*` | Main menu background and texture buttons. |
| Global UI | `res://assets/ui/global/textured_background.png`, `TimeProgressBar.png`, `TitleIcon.png`, `AppIcon.png` | Shared UI art and app icon. |
| Theme | `res://assets/ui/menagerie_theme.tres` | Project UI theme. |

## Audio assets

| Group | Paths | Runtime IDs |
| --- | --- | --- |
| Base music | `res://assets/audio/music/bgtheme.wav` | `music.bgtheme` |
| Dungeon music | `res://assets/audio/music/dungeon/*.wav` | `music.dungeon.*` |
| Ambience stems | `res://assets/audio/music/stems/ambience/*.wav` | `music.stems.ambience.*` |
| Boss SFX | `res://assets/audio/sfx/global/boss/BossStartFight.wav` | `sfx.global.boss.boss_start_fight` |
| Global SFX | `res://assets/audio/sfx/global/death/RunEndsLoop.wav` | `sfx.global.death.run_ends_loop` |
| UI sounds | `res://assets/audio/ui/button/Click.wav`, `res://assets/audio/ui/notification/SkillTreePoint.wav` | `ui.button.click`, `ui.notification.skill_tree_point` |

## Files not normally documented

- `.import` files are Godot import metadata.
- `.uid` files are Godot-generated resource IDs.
- Scene `.tmp` files are editor temp files.

## See also

- [[Audio IDs]]
- [[Battle visuals]]
- [[Adding audio]]
- [[Adding a battle visual]]
