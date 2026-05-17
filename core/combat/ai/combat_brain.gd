## Chooses AI combat actions and targets for either side using authored weights and difficulty-aware scoring.
class_name CombatBrain
extends RefCounted

const BEHAVIOR_RANDOM_WEIGHTED := "RandomWeighted"
const ROLE_DAMAGE := "Damage"
const ROLE_DEBUFF := "Debuff"
const ROLE_DEFENSE := "Defense"
const ROLE_FINISHER := "Finisher"
const STATUS_WEAKEN := "weaken"
const STATUS_VULNERABLE := "vulnerable"
const TEMPO_SCORE_WINDOW_SECONDS := 10.0
const MIN_EFFECTIVE_TIME_COST := 0.001
const CombatTargetingScript := preload("res://core/combat/actions/combat_targeting.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")

static func choose_action(
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource = null
) -> Dictionary:
	if actor == null or actor.hp <= 0:
		return {}

	var moves := _candidate_moves_for(actor)
	var valid_moves := _valid_moves(moves, actor, opponents, allies)
	if valid_moves.is_empty():
		return {}

	var move := _choose_move(_behavior_mode_for(actor), valid_moves, actor, opponents, allies, difficulty_profile)
	var targets := _targets_for_move(move, actor, opponents, allies)
	if targets.is_empty():
		return {}

	return {
		"action": move,
		"targets": targets,
	}

static func _candidate_moves_for(actor: Combatant) -> Array:
	if actor == null:
		return []

	if actor.profile != null and actor.profile.enemy_ai_profile != null:
		return actor.profile.enemy_ai_profile.moves.duplicate()

	return actor.actions.duplicate()

static func _behavior_mode_for(actor: Combatant) -> String:
	if actor != null and actor.profile != null and actor.profile.enemy_ai_profile != null:
		return str(actor.profile.enemy_ai_profile.behavior_mode)

	return BEHAVIOR_RANDOM_WEIGHTED

static func _valid_moves(
	moves: Array,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant]
) -> Array:
	var valid_moves: Array = []

	for move in moves:
		var action := move as CombatActionData
		if action == null:
			continue
		if not _is_actor_hp_in_range(actor, action):
			continue
		if _targets_for_move(action, actor, opponents, allies).is_empty():
			continue
		valid_moves.append(action)

	return valid_moves

static func _is_actor_hp_in_range(actor: Combatant, action: CombatActionData) -> bool:
	if actor == null or actor.max_hp <= 0:
		return false

	var hp_percent := float(actor.hp) / float(actor.max_hp)
	return hp_percent >= _action_float(action, "min_hp_percent", 0.0) and hp_percent <= _action_float(action, "max_hp_percent", 1.0)

static func _choose_move(
	behavior_mode: String,
	moves: Array,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource
) -> CombatActionData:
	match behavior_mode:
		BEHAVIOR_RANDOM_WEIGHTED:
			return _choose_random_or_scored(moves, actor, opponents, allies, difficulty_profile)
		_:
			return _choose_random_or_scored(moves, actor, opponents, allies, difficulty_profile)

static func _choose_random_or_scored(
	moves: Array,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource
) -> CombatActionData:
	var ai_randomness := ValueReaderScript.resource_float(difficulty_profile, "ai_randomness", 1.0)
	if randf() < ai_randomness:
		return _choose_weighted_random(moves, actor, opponents, allies, difficulty_profile)

	return _choose_highest_scored(moves, actor, opponents, allies, difficulty_profile)

static func _choose_weighted_random(
	moves: Array,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource
) -> CombatActionData:
	var scored_weights: Array[float] = []
	var total_weight := 0.0
	for move in moves:
		var action := move as CombatActionData
		var scored_weight: float = max(_action_weight(action), 0.0) * max(_score_move(action, actor, opponents, allies, difficulty_profile), 0.0)
		scored_weights.append(scored_weight)
		total_weight += scored_weight

	if total_weight <= 0.0:
		return _choose_authored_weighted_random(moves)

	var roll := randf() * total_weight
	var running_weight := 0.0
	for index in moves.size():
		running_weight += scored_weights[index]
		if roll <= running_weight:
			return moves[index] as CombatActionData

	return moves.back() as CombatActionData

static func _choose_authored_weighted_random(moves: Array) -> CombatActionData:
	var total_weight := 0.0
	for move in moves:
		total_weight += max(_action_weight(move as CombatActionData), 0.0)

	if total_weight <= 0.0:
		return moves.pick_random() as CombatActionData

	var roll := randf() * total_weight
	var running_weight := 0.0
	for move in moves:
		var action := move as CombatActionData
		running_weight += max(_action_weight(action), 0.0)
		if roll <= running_weight:
			return action

	return moves.back() as CombatActionData

static func _choose_highest_scored(
	moves: Array,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource
) -> CombatActionData:
	var best_move := moves[0] as CombatActionData
	var best_score := -INF
	for move in moves:
		var action := move as CombatActionData
		var score := _score_move(action, actor, opponents, allies, difficulty_profile)
		if score > best_score:
			best_move = action
			best_score = score

	return best_move

static func _score_move(
	action: CombatActionData,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource
) -> float:
	var targets := _score_targets_for_move(action, actor, opponents, allies)
	var target: Combatant = null
	if not targets.is_empty():
		target = targets[0]
	var actual_power := _estimate_action_power(action, actor, targets)
	var timing_awareness := ValueReaderScript.resource_float(difficulty_profile, "ai_timing_awareness", 0.0)
	var score_strength := ValueReaderScript.resource_float(difficulty_profile, "ai_score_strength", 0.0)
	var power_score := actual_power
	var tempo_score := _tempo_score(action, actor, actual_power)
	var base_score := lerpf(power_score, tempo_score, timing_awareness)
	var contextual_score := base_score

	contextual_score += _kill_bonus(target, actual_power, difficulty_profile)
	contextual_score += _role_bonus(action, actor, target, difficulty_profile)
	contextual_score -= _survival_time_penalty(action, actor, difficulty_profile)

	return max(lerpf(base_score, contextual_score, score_strength), 0.0)

static func _score_targets_for_move(
	action: CombatActionData,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant]
) -> Array[Combatant]:
	var target_rule: String = CombatTargetingScript.target_rule_for(action)
	match target_rule:
		CombatTargetingScript.TARGET_SELF, CombatTargetingScript.TARGET_ALL_ALLIES, CombatTargetingScript.TARGET_ALL_ENEMIES:
			return CombatTargetingScript.targets_for_action(action, actor, opponents, allies)

	var target := _best_target_for_score(opponents)
	var opponent_targets: Array[Combatant] = []
	if target != null:
		opponent_targets.append(target)
	return opponent_targets

static func _estimate_action_power(action: CombatActionData, actor: Combatant, targets: Array[Combatant]) -> float:
	var total_power := 0.0
	for effect_data in action.effect_data:
		total_power += max(CombatEffectLibrary.estimate_power(effect_data, actor, targets, action), 0.0)

	return total_power

static func _tempo_score(action: CombatActionData, actor: Combatant, actual_power: float) -> float:
	if actual_power <= 0.0:
		return 0.0

	return actual_power / _effective_time_cost(action, actor) * TEMPO_SCORE_WINDOW_SECONDS

static func _effective_time_cost(action: CombatActionData, actor: Combatant) -> float:
	var time_multiplier := 1.0
	if actor != null:
		time_multiplier = actor.action_time_multiplier

	return max(action.time_cost * time_multiplier, MIN_EFFECTIVE_TIME_COST)

static func _best_target_for_score(opponents: Array[Combatant]) -> Combatant:
	var best_target: Combatant = null
	for opponent in opponents:
		if opponent == null or opponent.hp <= 0:
			continue
		if best_target == null or opponent.hp < best_target.hp:
			best_target = opponent

	return best_target

static func _kill_bonus(target: Combatant, actual_power: float, difficulty_profile: Resource) -> float:
	if target == null or actual_power <= 0.0:
		return 0.0

	if actual_power < float(target.hp):
		return 0.0

	return 20.0 * ValueReaderScript.resource_float(difficulty_profile, "ai_finisher_priority", 0.0)

static func _role_bonus(
	action: CombatActionData,
	actor: Combatant,
	target: Combatant,
	difficulty_profile: Resource
) -> float:
	match _ai_role_for(action):
		ROLE_FINISHER:
			return 8.0 * ValueReaderScript.resource_float(difficulty_profile, "ai_finisher_priority", 0.0)
		ROLE_DEBUFF:
			return _debuff_score(action, target, difficulty_profile)
		ROLE_DEFENSE:
			return _defense_score(actor, difficulty_profile)
		_:
			return 0.0

static func _debuff_score(action: CombatActionData, target: Combatant, difficulty_profile: Resource) -> float:
	var status_id := _status_id_for(action)
	if target == null or status_id.is_empty():
		return 0.0

	var awareness := ValueReaderScript.resource_float(difficulty_profile, "ai_debuff_awareness", 0.0)
	if _target_has_status(target, status_id):
		return -12.0 * awareness

	if status_id == STATUS_WEAKEN or status_id == "status.weaken":
		return 8.0 * awareness
	if status_id == STATUS_VULNERABLE or status_id == "status.vulnerable":
		return 10.0 * awareness

	return 5.0 * awareness

static func _defense_score(actor: Combatant, difficulty_profile: Resource) -> float:
	if actor == null or actor.max_hp <= 0:
		return 0.0

	var missing_hp_percent := 1.0 - (float(actor.hp) / float(actor.max_hp))
	return missing_hp_percent * 12.0 * ValueReaderScript.resource_float(difficulty_profile, "ai_survival_awareness", 0.0)

static func _survival_time_penalty(action: CombatActionData, actor: Combatant, difficulty_profile: Resource) -> float:
	var survival_awareness := ValueReaderScript.resource_float(difficulty_profile, "ai_survival_awareness", 0.0)
	var danger := _actor_danger_percent(actor)
	return _effective_time_cost(action, actor) * danger * survival_awareness

static func _actor_danger_percent(actor: Combatant) -> float:
	if actor == null or actor.max_hp <= 0:
		return 0.0

	return 1.0 - (float(actor.hp) / float(actor.max_hp))

static func _targets_for_move(
	action: CombatActionData,
	actor: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant]
) -> Array[Combatant]:
	var target_rule: String = CombatTargetingScript.target_rule_for(action)
	match target_rule:
		CombatTargetingScript.TARGET_SINGLE_ENEMY, CombatTargetingScript.TARGET_RANDOM_ENEMY:
			return _random_alive_target(opponents)
		_:
			return CombatTargetingScript.targets_for_action(action, actor, opponents, allies)

static func _target_rule_for(action: CombatActionData) -> String:
	return CombatTargetingScript.target_rule_for(action)

static func _random_alive_target(combatants: Array[Combatant]) -> Array[Combatant]:
	var valid_targets: Array[Combatant] = []
	for combatant in combatants:
		if combatant != null and combatant.hp > 0:
			valid_targets.append(combatant)

	if valid_targets.is_empty():
		return []

	var selected_targets: Array[Combatant] = []
	selected_targets.append(valid_targets.pick_random())
	return selected_targets

static func _target_has_status(target: Combatant, status_id: String) -> bool:
	if target == null or status_id.is_empty() or not target.has_method("has_status"):
		return false

	return target.has_status(status_id)

static func _action_weight(action: CombatActionData) -> float:
	return _action_float(action, "weight", 1.0)

static func _ai_role_for(action: CombatActionData) -> String:
	var role := _action_string(action, "ai_role", "")
	if not role.is_empty():
		return role
	if _target_rule_for(action) == CombatTargetingScript.TARGET_SELF and _has_effect(action, CombatEffectLibrary.EFFECT_BLOCK):
		return ROLE_DEFENSE

	return ROLE_DAMAGE

static func _status_id_for(action: CombatActionData) -> String:
	var status_id := _action_string(action, "status_id", "")
	if not status_id.is_empty():
		return status_id

	if action == null:
		return ""

	for effect_data in action.effect_data:
		if not (effect_data is Dictionary):
			continue
		var effect_status_id: Variant = effect_data.get("status_id", "")
		if effect_status_id is String or effect_status_id is StringName:
			return str(effect_status_id)

	return ""

static func _has_effect(action: CombatActionData, effect_id: StringName) -> bool:
	if action == null:
		return false

	for effect_data in action.effect_data:
		if not (effect_data is Dictionary):
			continue
		var raw_id: Variant = effect_data.get("id", &"")
		if StringName(str(raw_id)) == effect_id:
			return true

	return false

static func _action_float(action: CombatActionData, field_name: String, default_value: float) -> float:
	if action == null:
		return default_value

	var value: Variant = action.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value

static func _action_string(action: CombatActionData, field_name: String, default_value: String) -> String:
	if action == null:
		return default_value

	var value: Variant = action.get(field_name)
	if value is String or value is StringName:
		return str(value)

	return default_value
