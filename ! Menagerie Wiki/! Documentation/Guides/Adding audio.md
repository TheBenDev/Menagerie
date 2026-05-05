---
title: Adding audio
page-type: guide
status: draft
---

Use this guide to add SFX, UI sounds, or music to the scanned audio catalog.

## Add the source file

Place audio under `res://assets/audio` using the intended namespace:

- `res://assets/audio/sfx/...`
- `res://assets/audio/ui/...`
- `res://assets/audio/music/...`

`AudioRegistry` creates IDs from the path. For example:

```text
res://assets/audio/sfx/global/boss/BossStartFight.wav -> sfx.global.boss.boss_start_fight
```

## Decide whether an authored cue is needed

You can use a scanned stream directly when default settings are fine.

Create or update an `AudioCueData` in `res://assets/audio/common_audio_library.tres` when you need:

- volume adjustment
- bus override
- pitch randomization
- cooldown
- max instance limit
- priority
- multiple stream variants

## Use SFX or UI playback

```gdscript
SoundManager.play_sfx(&"sfx.global.boss.boss_start_fight", {"priority": 7})
SoundManager.play_ui(&"ui.button.click")
```

Use `play_sfx()` for gameplay and `play_ui()` for interface sounds. Button click sounds are already auto-connected.

## Add music

1. Add the stream under `res://assets/audio/music`.
2. Add or update a `MusicTrackData` in `common_audio_library.tres`.
3. Set `base_stream_id` or playlist fields.
4. Add route mapping in `GameManager`'s scene music map if needed.
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
