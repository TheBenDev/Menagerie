## Carries source, target, amount, and mitigation flags before a target applies block and health loss.
class_name DamagePacket
extends RefCounted

var source: Combatant
var target: Combatant
var amount: int = 0
var ignore_block: bool = false

func _init(_source: Combatant, _target: Combatant, _amount: int, _ignore_block: bool = false) -> void:
	source = _source
	target = _target
	amount = _amount
	ignore_block = _ignore_block
