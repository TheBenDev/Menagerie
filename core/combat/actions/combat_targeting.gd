## Shared target resolution for player-selected actions and AI-controlled combatants.
class_name CombatTargeting
extends RefCounted

const TARGET_SINGLE_ENEMY := "SingleEnemy"
const TARGET_SINGLE_ALLY := "SingleAlly"
const TARGET_RANDOM_ENEMY := "RandomEnemy"
const TARGET_SELF := "Self"
const TARGET_ALL_ALLIES := "AllAllies"
const TARGET_ALL_ENEMIES := "AllEnemies"

const LEGACY_TARGET_RANDOM_OPPONENT := "RandomOpponent"
const LEGACY_TARGET_MANUAL_OPPONENT := "ManualOpponent"
const LEGACY_TARGET_ALL_OPPONENTS := "AllOpponents"

static func target_rule_for(action: CombatActionData) -> String:
	if action == null:
		return TARGET_SINGLE_ENEMY

	var raw_rule := _action_string(action, "target_rule", "")
	if raw_rule == TARGET_SINGLE_ENEMY and not action.target_enemy:
		return TARGET_SELF

	match raw_rule:
		"", LEGACY_TARGET_MANUAL_OPPONENT:
			return TARGET_SINGLE_ENEMY if action.target_enemy else TARGET_SELF
		LEGACY_TARGET_RANDOM_OPPONENT:
			return TARGET_RANDOM_ENEMY
		LEGACY_TARGET_ALL_OPPONENTS:
			return TARGET_ALL_ENEMIES
		_:
			return raw_rule

static func requires_manual_target(action: CombatActionData) -> bool:
	var target_rule := target_rule_for(action)
	return target_rule == TARGET_SINGLE_ENEMY or target_rule == TARGET_SINGLE_ALLY

static func manual_targets_for_action(
	action: CombatActionData,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant]
) -> Array[Combatant]:
	match target_rule_for(action):
		TARGET_SINGLE_ALLY:
			return living_targets(allies)
		TARGET_SINGLE_ENEMY:
			return living_targets(opponents)
		_:
			return targets_for_action(action, actor, opponents, allies)

static func targets_for_action(
	action: CombatActionData,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	explicit_targets: Array[Combatant] = []
) -> Array[Combatant]:
	var target_rule := target_rule_for(action)
	if _uses_explicit_targets(target_rule):
		var targets := living_targets(explicit_targets)
		if not targets.is_empty():
			return targets

	match target_rule:
		TARGET_SELF:
			return _self_target(actor)
		TARGET_ALL_ALLIES:
			return living_targets(allies)
		TARGET_ALL_ENEMIES:
			return living_targets(opponents)
		TARGET_RANDOM_ENEMY:
			return _random_living_target(opponents)
		TARGET_SINGLE_ALLY:
			return _first_living_target(allies)
		TARGET_SINGLE_ENEMY:
			return _first_living_target(opponents)
		_:
			return _first_living_target(opponents)

static func living_targets(raw_targets: Array) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	for raw_target in raw_targets:
		var target := raw_target as Combatant
		if target != null and target.hp > 0 and not targets.has(target):
			targets.append(target)

	return targets

static func _uses_explicit_targets(target_rule: String) -> bool:
	return target_rule == TARGET_SINGLE_ENEMY or target_rule == TARGET_SINGLE_ALLY

static func _self_target(actor: Combatant) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	if actor != null and actor.hp > 0:
		targets.append(actor)
	return targets

static func _first_living_target(combatants: Array[Combatant]) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	for combatant in combatants:
		if combatant != null and combatant.hp > 0:
			targets.append(combatant)
			return targets

	return targets

static func _random_living_target(combatants: Array[Combatant]) -> Array[Combatant]:
	var targets := living_targets(combatants)
	if targets.is_empty():
		return targets

	var selected_targets: Array[Combatant] = []
	selected_targets.append(targets.pick_random())
	return selected_targets

static func _action_string(action: CombatActionData, field_name: String, default_value: String) -> String:
	if action == null:
		return default_value

	var value: Variant = action.get(field_name)
	if value is String or value is StringName:
		return str(value)

	return default_value
