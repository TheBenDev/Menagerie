---
title: Modular class kit refactor
page-type: refactor-plan
status: implemented
---

# Modular Class Kit Refactor

## Summary

- Warrior class kit plumbing was migrated to shared class profile, run state, kit builder, reward service, stance data, and class combatant scripts.
- Warrior class data now discovers actions, stances, passives, rewards, and upgrades from `res://scenes/combatants/characters/warrior/class`.
- Blood Surge now uses generic `resource_costs` and `resource.refund` instead of a Warrior-specific low-HP Rage refund effect.

## Notes

- Stance switch timing was preserved at the currently authored `1.0` second value.
- The Warrior design page still says stance changes take `5` seconds; confirm the intended timing before rebalancing.
- Passive rewards remain metadata only; executable passive hooks were intentionally left out of this pass.
