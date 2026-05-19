# Audio Routing Migration

## Target

`MusicDirector` decides what music should play. `SoundManager` only performs playback mechanics.

## Migration Notes

- `SceneRouteService` must contain no music constants or route-to-music mapping.
- `GameManager` should notify route/run state changes, not call `SoundManager.play_music()` directly for route music.
- `CombatAudioBridge` should send combat pressure/intensity to `MusicDirector`.
- Combat scene routing now keeps playback on the dungeon playlist and applies combat state IDs over that run music context; `music.combat` remains authored with dungeon playlist streams so direct calls cannot fall back to `music.bgtheme`.

## Documentation Follow-Up

- Update audio flow and audio API docs after routing migration settles. Current formal docs still describe `combat/BattleScene` as `music.combat` backed by `music.bgtheme`.
