---
title: Adding audio
page-type: guide
status: draft
---

Use this guide to add SFX, UI sounds, or music to the scanned audio catalog.

## Add the source file

Place audio under `res://sounds` using the intended namespace:

- `res://sounds/sfx/...`
- `res://sounds/ui/...`
- `res://sounds/music/...`

`AudioRegistry` creates IDs from the path. For example:

```text
res://sounds/sfx/Boss/BossStartFight.wav -> sfx.boss.boss_start_fight
```

## Decide whether an authored cue is needed

You can use a scanned stream directly when default settings are fine.

Create or update an `AudioCueData` in `res://data/audio/common_audio_library.tres` when you need:

- volume adjustment
- bus override
- pitch randomization
- cooldown
- max instance limit
- priority
- multiple stream variants

## Use SFX or UI playback

```gdscript
SoundManager.play_sfx(&"sfx.boss.boss_start_fight", {"priority": 7})
SoundManager.play_ui(&"ui.button.click")
```

Use `play_sfx()` for gameplay and `play_ui()` for interface sounds. Button click sounds are already auto-connected.

## Add music

1. Add the stream under `res://sounds/music`.
2. Add or update a `MusicTrackData` in `common_audio_library.tres`.
3. Set `base_stream_id` or playlist fields.
4. Add route mapping in `GameManager._music_id_for_scene_path()` if needed.
5. Use `SoundManager.set_music_state()` only when the track has state variants.

## Validate behavior

- Check the ID in [[Audio IDs]] or with `SoundManager.get_registered_audio_stream_ids()`.
- Confirm missing stream warnings do not appear.
- Confirm buses are `Music`, `SFX`, `UI`, or `Master`.
- Run the headless load command after resource changes.

## See also

- [[Audio flow]]
- [[Audio IDs]]
- [[Autoload APIs]]
- [[Asset inventory]]
