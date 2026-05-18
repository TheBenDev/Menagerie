# Audio Routing Migration

## Target

`MusicDirector` decides what music should play. `SoundManager` only performs playback mechanics.

## Migration Notes

- `SceneRouteService` must contain no music constants or route-to-music mapping.
- `GameManager` should notify route/run state changes, not call `SoundManager.play_music()` directly for route music.
- `CombatAudioBridge` should send combat pressure/intensity to `MusicDirector`.

## Documentation Follow-Up

- Update audio flow and audio API docs after routing migration settles.
