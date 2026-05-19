# Multiplayer Foundation Notes

## Assumptions For This Pass

- One local player controls one party member.
- Non-player party members can follow or act through AI/autopilot helpers.
- `PartyControlMode.REMOTE_PLAYER` stays available as a future enum value.
- No networking, lobby transport, authority replication, or interchangeable party control will be added during this refactor.

## Future Authority Boundaries

- `PartyManager` owns party/member state.
- `DungeonManager` owns map movement and dungeon node authority.
- `CombatManager` owns combat session authority.
- `GameManager` remains the high-level lifecycle coordinator.
