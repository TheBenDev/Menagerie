## Enemy-only combat action data with AI weights, target rules, HP gates, and role metadata.
class_name EnemyMoveData
extends "res://core/combat/data/actions/combat_action_data.gd"

const TARGET_RANDOM_OPPONENT := "RandomOpponent"
const TARGET_SELF := "Self"

const ROLE_DAMAGE := "Damage"
const ROLE_HEAVY_DAMAGE := "HeavyDamage"
const ROLE_DEBUFF := "Debuff"
const ROLE_DEFENSE := "Defense"
const ROLE_HEAL := "Heal"
const ROLE_SETUP := "Setup"
const ROLE_FINISHER := "Finisher"

@export var weight: float = 1.0
@export_enum("RandomOpponent", "Self") var target_rule: String = TARGET_RANDOM_OPPONENT
@export_range(0.0, 1.0, 0.01) var min_hp_percent: float = 0.0
@export_range(0.0, 1.0, 0.01) var max_hp_percent: float = 1.0
@export var cooldown_seconds: float = 0.0

@export_enum("Damage", "HeavyDamage", "Debuff", "Defense", "Heal", "Setup", "Finisher") var ai_role: String = ROLE_DAMAGE
@export var status_id: String = ""
@export var prefer_low_hp_targets: bool = false
@export var prefer_vulnerable_targets: bool = false
@export var prefer_weakened_targets: bool = false
@export var avoid_if_target_vulnerable: bool = false
@export var avoid_if_target_weakened: bool = false
