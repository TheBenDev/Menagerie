# Party Manager Migration

## Target

`PartyManager` owns party setup, selected character lookup, selected member state, and party-state bridge helpers.

## Current Multiplayer Assumptions

- One player controls one party member.
- Non-player members are AI controlled.
- `REMOTE_PLAYER` remains reserved for future use.
- No multiplayer transport or interchangeable control is implemented during this refactor.

## Documentation Follow-Up

- Update party/member control docs after the runtime ownership is stable.
