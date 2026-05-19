# Refactor Index

This folder tracks the production hardening and manager-architecture refactor while the formal documentation is intentionally deferred.

## Phase Notes

- [[01 Production hardening]]
- [[02 Manager architecture]]
- [[03 Dungeon manager migration]]
- [[04 Combat manager migration]]
- [[05 Party manager migration]]
- [[06 Audio routing migration]]
- [[07 Multiplayer foundation notes]]

## Current Rules

- No compatibility layer: unsupported legacy fields, fallback enemies, fallback dungeon paths, fallback difficulty values, and silent repair paths should be removed.
- Invalid authored/generated data should fail loudly and be fixed at the source.
- Formal documentation updates are tracked here and in `!IGNORE/menagerie_refactor_implementation_plan.md` until the architecture stabilizes.
