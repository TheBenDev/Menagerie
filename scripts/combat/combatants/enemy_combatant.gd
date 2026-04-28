class_name EnemyCombatant
extends "res://scripts/combat/combatants/combatant.gd"

func _ready() -> void:
	is_enemy = true
	super._ready()
