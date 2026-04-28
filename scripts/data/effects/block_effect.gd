class_name BlockEffect
extends "res://scripts/data/effects/action_effect.gd"

@export var base_block: int = 0

func apply(source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> void:
	if source == null or not source.has_method("add_block"):
		return

	source.add_block(base_block)

func estimate_power(_source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> float:
	return float(max(base_block, 0))
