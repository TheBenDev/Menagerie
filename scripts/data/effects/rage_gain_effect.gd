## Action effect that grants rage to sources implementing gain_rage.
class_name RageGainEffect
extends "res://scripts/data/effects/action_effect.gd"

func _init() -> void:
	effect_id = CombatEffectLibrary.EFFECT_RAGE_GAIN

func apply(source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> void:
	if source == null or not source.has_method("gain_rage"):
		return

	source.gain_rage(amount)
