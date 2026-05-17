## Allocates level-scaled combatant stats from profile stat weights and game difficulty budgets.
class_name CombatantStatAllocator
extends RefCounted

const STAT_STRENGTH := "STR"
const STAT_DEXTERITY := "DEX"
const STAT_INTELLIGENCE := "INT"
const STAT_VITALITY := "VIT"
const STAT_IDS := [
	STAT_STRENGTH,
	STAT_DEXTERITY,
	STAT_INTELLIGENCE,
	STAT_VITALITY,
]
const DEFAULT_WEIGHT := 1.0
const ValueReaderScript := preload("res://core/utils/value_reader.gd")

static func allocate_enemy_stats(profile: Resource, difficulty_profile: Resource, enemy_level: int, stat_seed: int) -> Dictionary:
	var budget: int = enemy_stat_budget(difficulty_profile, enemy_level)
	var weights: Dictionary = stat_weights_for_profile(profile)
	return _roll_weighted_stats(budget, weights, stat_seed)

static func enemy_stat_budget(difficulty_profile: Resource, enemy_level: int) -> int:
	var base_budget: int = ValueReaderScript.resource_int(difficulty_profile, "enemy_stat_budget", 10)
	var baseline_budget: int = ValueReaderScript.resource_int(difficulty_profile, "enemy_baseline_stat_budget", 5)
	var points_per_level: int = ValueReaderScript.resource_int(difficulty_profile, "enemy_stat_points_per_level", 2)
	return maxi(base_budget + baseline_budget + maxi(enemy_level, 0) * maxi(points_per_level, 0), 0)

static func stat_weights_for_profile(profile: Resource) -> Dictionary:
	var weights: Dictionary = {}
	if profile != null:
		var raw_weights: Variant = profile.get("stat_weights")
		if raw_weights is Dictionary:
			weights = raw_weights.duplicate()

	var normalized_weights: Dictionary = {}
	var total_weight: float = 0.0
	for stat_id in STAT_IDS:
		var weight: float = maxf(_weight_value(weights, stat_id, DEFAULT_WEIGHT), 0.0)
		normalized_weights[stat_id] = weight
		total_weight += weight

	if total_weight <= 0.0:
		for stat_id in STAT_IDS:
			normalized_weights[stat_id] = DEFAULT_WEIGHT

	return normalized_weights

static func apply_stats_to_combatant(combatant: Combatant, stats: Dictionary) -> void:
	if combatant == null:
		return

	combatant.strength = max(int(stats.get(STAT_STRENGTH, combatant.strength)), 0)
	combatant.dexterity = max(int(stats.get(STAT_DEXTERITY, combatant.dexterity)), 0)
	combatant.intelligence = max(int(stats.get(STAT_INTELLIGENCE, combatant.intelligence)), 0)
	combatant.vitality = max(int(stats.get(STAT_VITALITY, combatant.vitality)), 0)

static func _roll_weighted_stats(budget: int, weights: Dictionary, stat_seed: int) -> Dictionary:
	var stats: Dictionary = {
		STAT_STRENGTH: 0,
		STAT_DEXTERITY: 0,
		STAT_INTELLIGENCE: 0,
		STAT_VITALITY: 0,
	}
	if budget <= 0:
		return stats

	var rng := RandomNumberGenerator.new()
	var resolved_seed: int = int(abs(stat_seed))
	if resolved_seed <= 0:
		resolved_seed = 1
	rng.seed = resolved_seed
	var total_weight: float = _total_weight(weights)
	for index in range(budget):
		var selected_stat: String = _roll_stat_id(weights, total_weight, rng)
		stats[selected_stat] = int(stats.get(selected_stat, 0)) + 1

	return stats

static func _roll_stat_id(weights: Dictionary, total_weight: float, rng: RandomNumberGenerator) -> String:
	if total_weight <= 0.0:
		return STAT_IDS[rng.randi_range(0, STAT_IDS.size() - 1)]

	var roll := rng.randf() * total_weight
	var running_weight := 0.0
	for stat_id in STAT_IDS:
		running_weight += max(float(weights.get(stat_id, DEFAULT_WEIGHT)), 0.0)
		if roll <= running_weight:
			return stat_id

	return STAT_VITALITY

static func _total_weight(weights: Dictionary) -> float:
	var total_weight := 0.0
	for stat_id in STAT_IDS:
		total_weight += max(float(weights.get(stat_id, DEFAULT_WEIGHT)), 0.0)
	return total_weight

static func _weight_value(weights: Dictionary, stat_id: String, default_value: float) -> float:
	if weights.has(stat_id):
		return float(weights[stat_id])

	var lower_key := stat_id.to_lower()
	if weights.has(lower_key):
		return float(weights[lower_key])

	return default_value
