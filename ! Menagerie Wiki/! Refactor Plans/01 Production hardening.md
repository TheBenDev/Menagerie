# Production Hardening

## Intent

Harden the current runtime contracts before moving responsibility into new managers.

## Required Contracts

- Dungeon descriptors must include `id`, `type`, and explicit `connections`.
- Fight and Boss descriptors must include `combat_encounter_id` and non-empty generated `enemy_instances`.
- Runtime enemy instances use `instance_id`, `profile_path`, `slot_id`, `level`, and `stat_seed`.
- Combat actions use `target_rule` as the only targeting contract.

## Removed Legacy Paths

- Fallback dungeon descriptor sets.
- Linear dungeon graph fallback generation.
- Combat fallback enemy startup.
- Broad difficulty reward multipliers.

## Documentation Follow-Up

- Update formal dungeon descriptor, combat payload, targeting, and difficulty docs after the refactor stabilizes.
