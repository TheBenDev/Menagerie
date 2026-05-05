---
title: Adding a scene route
page-type: guide
status: draft
---

Use this guide to add a new scene that can be loaded through `GameManager.go_to_scene()`.

## Create the scene

1. Create the `.tscn` under `res://scenes`.
2. Add a scene script beside the scene, such as under `res://scenes/ui`, `res://scenes/dungeon`, `res://scenes/combat`, or another appropriate subsystem.
3. Save the scene through Godot so resource serialization and UIDs are editor-owned.

## Route naming

`GameManager.scene_path_for()` accepts:

- `new_scene`
- `Folder/NewScene`
- `scenes/Folder/NewScene`
- `res://scenes/Folder/NewScene.tscn`

Prefer a short route ref without extension for call sites.

## Add music mapping

If the scene needs route music:

1. Add or reuse a music track in `res://assets/audio/common_audio_library.tres`.
2. Update `GameManager`'s scene music map.
3. Confirm `GameManager.play_music_for_scene(route)` resolves the new mapping.

## Add call sites

Use:

```gdscript
GameManager.go_to_scene("new_scene")
```

Avoid direct `get_tree().change_scene_to_file()` calls unless there is a specific reason to bypass route music and route normalization.

## Validate behavior

- Call `GameManager.scene_path_for(route)` and confirm the resolved path.
- Navigate to the scene from the intended UI or flow.
- Confirm route music changes as expected.
- Run the headless load command after changing scripts/scenes/resources.

## See also

- [[Scene routes]]
- [[Autoload APIs]]
- [[Audio flow]]
- [[Adding audio]]
