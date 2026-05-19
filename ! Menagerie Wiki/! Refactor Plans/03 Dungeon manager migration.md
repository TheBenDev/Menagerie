# Dungeon Manager Migration

## Target

`DungeonManager` becomes the single doorway for dungeon state changes.

## Migration Notes

- `DungeonController` should create views, handle input, and refresh from manager snapshots.
- Descriptor validation, pawn travel, node visit/reveal/resolve, encounter results, and combat-node completion belong in `DungeonManager`.
- Fight/Boss nodes must not route to combat unless their canonical runtime enemy instances are valid.

## Documentation Follow-Up

- Update dungeon flow and descriptor contract docs after manager migration settles.
