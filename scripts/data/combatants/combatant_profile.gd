class_name CombatantProfile
extends Resource

@export var display_name: String = "Combatant"
@export var placeholder_color: Color = Color(0.22, 0.24, 0.28)
@export var timeline_initial: String = "?"
@export var timeline_color: Color = Color.WHITE
@export var strength: int = 0
@export var dexterity: int = 0
@export var intelligence: int = 0
@export var vitality: int = 0
@export var moveset: Resource = null
@export var enemy_ai_profile: EnemyAIProfile = null
@export var reward_profile: Resource = null
@export var health_bar: Resource = null
@export var resource_bars: Array[Resource] = []
