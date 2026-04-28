class_name DifficultyProfile
extends Resource

@export var id: String = "normal"
@export var display_name: String = "Normal"

@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var enemy_time_cost_multiplier: float = 1.0
@export var reward_multiplier: float = 1.0

@export_range(0.0, 1.0, 0.01) var ai_randomness: float = 0.45
@export_range(0.0, 1.0, 0.01) var ai_score_strength: float = 0.60
@export_range(0.0, 1.0, 0.01) var ai_survival_awareness: float = 0.50
@export_range(0.0, 1.0, 0.01) var ai_finisher_priority: float = 0.50
@export_range(0.0, 1.0, 0.01) var ai_debuff_awareness: float = 0.50
@export_range(0.0, 1.0, 0.01) var ai_timing_awareness: float = 0.50
