class_name ActionResolver
extends RefCounted

static func resolve_action(source: Combatant, targets: Array[Combatant], action: CombatActionData) -> void:
	if source == null or action == null:
		return

	_apply_costs(source, action)
	_apply_effects(source, targets, action)

static func _apply_costs(source: Combatant, action: CombatActionData) -> void:
	if action.hp_cost > 0:
		source.hp = max(source.hp - action.hp_cost, 1)
		source.hp_changed.emit(source)

static func _apply_effects(source: Combatant, targets: Array[Combatant], action: CombatActionData) -> void:
	for effect in action.effects:
		if effect != null and effect.has_method("apply"):
			effect.apply(source, targets, action)
