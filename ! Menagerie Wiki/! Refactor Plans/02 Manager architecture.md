# Manager Architecture

## Boundaries

- `GameManager`: high-level run lifecycle, route changes, run shell, signals, delegation.
- `SceneRouteService`: route IDs, scene paths, normalization, validation.
- `DifficultyService`: active difficulty ID, profile lookup, validation, difficulty-specific data access.
- `PartyManager`: party composition, character profile lookup, member state, party reward application.
- `DungeonManager`: dungeon generation, descriptor validation, map state, pawn flow, node resolution, dungeon snapshots.
- `CombatManager`: combat setup, payload validation, session context, result handling.
- `MusicDirector`: music decisions from route/run/dungeon/combat context.
- `SoundManager`: playback mechanics, buses, cues, crossfades, stream lookup.
- `RewardService`: reward package calculation from actual combat/event context.

## Startup Rule

Autoload startup must stay lightweight. Managers should not generate floors, scan large resource sets, instantiate scenes, or start combat until requested.
