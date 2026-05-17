## Chooses enemy actions and targets using authored move weights plus difficulty-aware scoring.
class_name EnemyBrain
extends RefCounted

const BEHAVIOR_RANDOM_WEIGHTED := "RandomWeighted"
const STATUS_WEAKEN := "weaken"
const STATUS_VULNERABLE := "vulnerable"
const TEMPO_SCORE_WINDOW_SECONDS := 10.0
const MIN_EFFECTIVE_TIME_COST := 0.001
const ValueReaderScript := preload("res://core/utils/value_reader.gd")

static func choose_action(
	enemy: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant],
	difficulty_profile: Resource = null
) -> Dictionary:
	var ai_profile := _ai_profile_for(enemy)
	if ai_profile == null:
		return {}

	var valid_moves := _valid_moves(ai_profile, enemy, opponents, allies)
	if valid_moves.is_empty():
		return {}

	var move := _choose_move(ai_profile, valid_moves, enemy, opponents, difficulty_profile)
	var targets := _targets_for_move(move, enemy, opponents, allies)
	if targets.is_empty():
		return {}

	return {
		"action": move,
		"targets": targets,
	}

static func _ai_profile_for(enemy: Combatant) -> EnemyAIProfile:
	if enemy == null or enemy.profile == null:
		return null

	return enemy.profile.enemy_ai_profile

static func _valid_moves(
	ai_profile: EnemyAIProfile,
	enemy: Combatant,
	opponents: Array[Combatant],
	allies: Array[Combatant]
) -> Array[EnemyMoveData]:
	var moves: Array[EnemyMoveData] = []

	for move in ai_profile.moves:
		if move == null:
			continue
		if not _is_enemy_hp_in_range(enemy, move):
			continue
		if _targets_for_move(move, enemy, opponents, allies).is_empty():
			continue
		moves.append(move)

	return moves

static func _is_enemy_hp_in_range(enemy: Combatant, move: EnemyMoveData) -> bool:
	if enemy == null or enemy.max_hp <= 0:
		return false

	var hp_percent := float(enemy.hp) / float(enemy.max_hp)
	return hp_percent >= move.min_hp_percent and hp_percent <= move.max_hp_percent

static func _choose_move(
	ai_profile: EnemyAIProfile,
	moves: Array[EnemyMoveData],
	enemy: Combatant,
	opponents: Array[Combatant],
	difficulty_profile: Resource
) -> EnemyMoveData:
	match ai_profile.behavior_mode:
		BEHAVIOR_RANDOM_WEIGHTED:
			return _choose_random_or_scored(moves, enemy, opponents, difficulty_profile)
		_:
			return _choose_random_or_scored(moves, enemy, opponents, difficulty_profile)

static func _choose_random_or_scored(
	moves: Array[EnemyMoveData],
	enemy: Combatant,
	opponents: Array[Combatant],
	difficulty_profile: Resource
) -> EnemyMoveData:
	var ai_randomness := ValueReaderScript.resource_float(difficulty_profile, "ai_randomness", 1.0)
	if randf() < ai_randomness:
		return _choose_weighted_random(moves, enemy, opponents, difficulty_profile)

	return _choose_highest_scored(moves, enemy, opponents, difficulty_profile)

static func _choose_weighted_random(
	moves: Array[EnemyMoveData],
	enemy: Combatant,
	opponents: Array[Combatant],
	difficulty_profile: Resource
) -> EnemyMoveData:
	var scored_weights: Array[float] = []
	var total_weight := 0.0
	for move in moves:
		var scored_weight: float = max(move.weight, 0.0) * max(_score_move(move, enemy, opponents, difficulty_profile), 0.0)
		scored_weights.append(scored_weight)
		total_weight += scored_weight

	if total_weight <= 0.0:
		return _choose_authored_weighted_random(moves)

	var roll := randf() * total_weight
	var running_weight := 0.0
	for index in moves.size():
		running_weight += scored_weights[index]
		if roll <= running_weight:
			return moves[index]

	return moves.back()

static func _choose_authored_weighted_random(moves: Array[EnemyMoveData]) -> EnemyMoveData:
	var total_weight := 0.0
	for move in moves:
		total_weight += max(move.weight, 0.0)

	if total_weight <= 0.0:
		return moves.pick_random()

	var roll := randf() * total_weight
	var running_weight := 0.0
	for move in moves:
		running_weight += max(move.weight, 0.0)
		if roll <= running_weight:
			return move

	return moves.back()

static func _choose_highest_scored(
	moves: Array[EnemyMoveData],
	enemy: Combatant,
	opponents: Array[Combatant],
	difficulty_profile: Resource
) -> EnemyMoveData:
	var best_move := moves[0]
	var best_score := -INF
	for move in moves:
		var score := _score_move(move, enemy, opponents, difficulty_profile)
		if score > best_score:
			best_move = move
			best_score = score

	return best_move

static func _score_move(
	move: EnemyMoveData,
	enemy: Combatant,
	opponents: Array[Combatant],
	difficulty_profile: Resource
) -> float:
	var targets := _score_targets_for_move(move, enemy, opponents)
	var target: Combatant = null
	if not targets.is_empty():
		target = targets[0]
	var actual_power := _estimate_action_power(move, enemy, targets)
	var timing_awareness := ValueReaderScript.resource_float(difficulty_profile, "ai_timing_awareness", 0.0)
	var score_strength := ValueReaderScript.resource_float(difficulty_profile, "ai_score_strength", 0.0)
	var power_score := actual_power
	var tempo_score := _tempo_score(move, enemy, actual_power)
	var base_score := lerpf(power_score, tempo_score, timing_awareness)
	var contextual_score := base_score

	contextual_score += _kill_bonus(target, actual_power, difficulty_profile)
	contextual_score += _role_bonus(move, enemy, target, difficulty_profile)
	contextual_score -= _survival_time_penalty(move, enemy, difficulty_profile)

	return max(lerpf(base_score, contextual_score, score_strength), 0.0)

static func _score_targets_for_move(
	move: EnemyMoveData,
	enemy: Combatant,
	opponents: Array[Combatant]
) -> Array[Combatant]:
	match move.target_rule:
		EnemyMoveData.TARGET_SELF:
			var self_targets: Array[Combatant] = []
			if enemy != null and enemy.hp > 0:
				self_targets.append(enemy)
			return self_targets
		_:
			var target := _best_target_for_score(opponents)
			var opponent_targets: Array[Combatant] = []
			if target != null:
				opponent_targets.append(target)
			return opponent_targets

static func _estimate_action_power(move: EnemyMoveData, enemy: Combatant, targets: Array[Combatant]) -> float:
	var total_power := 0.0
	for effect_data in move.effect_data:
		total_power += max(CombatEffectLibrary.estimate_power(effect_data, enemy, targets, move), 0.0)

	return total_power

static func _tempo_score(move: EnemyMoveData, enemy: Combatant, actual_power: float) -> float:
	if actual_power <= 0.0:
		return 0.0

	return actual_power / _effective_time_cost(move, enemy) * TEMPO_SCORE_WINDOW_SECONDS

static func _effective_time_cost(move: EnemyMoveData, enemy: Combatant) -> float:
	var time_multiplier := 1.0
	if enemy != null:
		time_multiplier = enemy.action_time_multiplier

	return max(move.time_cost * time_multiplier, MIN_EFFECTIVE_TIME_COST)

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
	move: EnemyMoveData,
	enemy: Combatant,
	target: Combatant,
	difficulty_profile: Resource
) -> float:
	match move.ai_role:
		EnemyMoveData.ROLE_FINISHER:
			return 8.0 * ValueReaderScript.resource_float(difficulty_profile, "ai_finisher_priority", 0.0)
		EnemyMoveData.ROLE_DEBUFF:
			return _debuff_score(move, target, difficulty_profile)
		EnemyMoveData.ROLE_DEFENSE:
			return _defense_score(enemy, difficulty_profile)
		_:
			return 0.0

static func _debuff_score(move: EnemyMoveData, target: Combatant, difficulty_profile: Resource) -> float:
	if target == null or move.status_id.is_empty():
		return 0.0

	var awareness := ValueReaderScript.resource_float(difficulty_profile, "ai_debuff_awareness", 0.0)
	if _target_has_status(target, move.status_id):
		return -12.0 * awareness

	if move.status_id == STATUS_WEAKEN:
		return 8.0 * awareness
	if move.status_id == STATUS_VULNERABLE:
		return 10.0 * awareness

	return 5.0 * awareness

static func _defense_score(enemy: Combatant, difficulty_profile: Resource) -> float:
	if enemy == null or enemy.max_hp <= 0:
		return 0.0

	var missing_hp_percent := 1.0 - (float(enemy.hp) / float(enemy.max_hp))
	return missing_hp_percent * 12.0 * ValueReaderScript.resource_float(difficulty_profile, "ai_survival_awareness", 0.0)

static func _survival_time_penalty(move: EnemyMoveData, enemy: Combatant, difficulty_profile: Resource) -> float:
	var survival_awareness := ValueReaderScript.resource_float(difficulty_profile, "ai_survival_awareness", 0.0)
	var danger := _enemy_danger_percent(enemy)
	return _effective_time_cost(move, enemy) * danger * survival_awareness

static func _enemy_danger_percent(enemy: Combatant) -> float:
	if enemy == null or enemy.max_hp <= 0:
		return 0.0

	return 1.0 - (float(enemy.hp) / float(enemy.max_hp))

static func _targets_for_move(
	move: EnemyMoveData,
	enemy: Combatant,
	opponents: Array[Combatant],
	_allies: Array[Combatant]
) -> Array[Combatant]:
	match move.target_rule:
		EnemyMoveData.TARGET_SELF:
			var targets: Array[Combatant] = []
			if enemy != null and enemy.hp > 0:
				targets.append(enemy)
			return targets
		EnemyMoveData.TARGET_RANDOM_OPPONENT:
			return _random_alive_target(opponents)
		_:
			return _random_alive_target(opponents)

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
