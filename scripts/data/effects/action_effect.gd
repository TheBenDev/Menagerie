class_name ActionEffect
extends Resource

func apply(_source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> void:
	pass

func estimate_power(_source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> float:
	return 0.0
