class_name RageGainEffect
extends "res://scripts/data/effects/action_effect.gd"

@export var amount: int = 0

func apply(source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> void:
	if source == null or not source.has_method("gain_rage"):
		return

	source.gain_rage(amount)
