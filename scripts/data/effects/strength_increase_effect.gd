## Action effect that permanently adjusts strength for chosen targets or the source when no target is supplied.
class_name StrengthIncreaseEffect
extends "res://scripts/data/effects/action_effect.gd"

func _init() -> void:
	effect_id = CombatEffectLibrary.EFFECT_STRENGTH_ADD
	amount = 1

func apply(source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> void:
	if amount == 0:
		return

	var affected_targets: Array[Combatant] = targets.duplicate()
	if affected_targets.is_empty() and source != null:
		affected_targets.append(source)

	for target in affected_targets:
		if target == null or target.hp <= 0:
			continue

		target.strength = max(target.strength + amount, 0)

func estimate_power(_source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> float:
	if amount <= 0:
		return 0.0

	return float(amount * max(targets.size(), 1) * 4)
