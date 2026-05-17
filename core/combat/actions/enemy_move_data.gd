## Enemy-only combat action data with AI weights, HP gates, and role metadata.
class_name EnemyMoveData
extends "res://core/combat/actions/combat_action_data.gd"

const ROLE_DAMAGE := "Damage"
const ROLE_HEAVY_DAMAGE := "HeavyDamage"
const ROLE_DEBUFF := "Debuff"
const ROLE_DEFENSE := "Defense"
const ROLE_HEAL := "Heal"
const ROLE_SETUP := "Setup"
const ROLE_FINISHER := "Finisher"

@export var weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var min_hp_percent: float = 0.0
@export_range(0.0, 1.0, 0.01) var max_hp_percent: float = 1.0
;# Reserved for future AI memory/pacing; current enemy choice intentionally ignores cooldowns.
@export var cooldown_seconds: float = 0.0

@export_enum("Damage", "HeavyDamage", "Debuff", "Defense", "Heal", "Setup", "Finisher") var ai_role: String = ROLE_DAMAGE
@export var status_id: String = ""
;# Reserved for future target scoring once party combat introduces multiple opponents.
@export var prefer_low_hp_targets: bool = false
;# Reserved for future target scoring once party combat introduces multiple opponents.
@export var prefer_vulnerable_targets: bool = false
;# Reserved for future target scoring once party combat introduces multiple opponents.
@export var prefer_weakened_targets: bool = false
;# Reserved for future target scoring once party combat introduces multiple opponents.
@export var avoid_if_target_vulnerable: bool = false
;# Reserved for future target scoring once party combat introduces multiple opponents.
@export var avoid_if_target_weakened: bool = false
