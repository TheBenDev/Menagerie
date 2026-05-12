## Carries source, target, and amount before a target applies block and health loss.
class_name DamagePacket
extends RefCounted

var source: Combatant
var target: Combatant
var amount: int = 0

func _init(_source: Combatant, _target: Combatant, _amount: int) -> void:
	source = _source
	target = _target
	amount = _amount
