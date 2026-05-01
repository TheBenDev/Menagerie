## Combatant specialization that marks itself as an enemy before applying profile data.
class_name EnemyCombatant
extends "res://scenes/combatants/combatant.gd"

func _ready() -> void:
	is_enemy = true
	super._ready()
