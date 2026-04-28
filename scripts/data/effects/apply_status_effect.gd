class_name ApplyStatusEffect
extends "res://scripts/data/effects/action_effect.gd"

@export var status_data: Resource = null
@export var duration_override_seconds: float = -1.0

func apply(_source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> void:
	if status_data == null:
		return

	for target in targets:
		if target == null or target.hp <= 0 or not target.has_method("add_status"):
			continue
		target.add_status(status_data, duration_override_seconds)
