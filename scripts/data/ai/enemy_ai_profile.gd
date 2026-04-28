class_name EnemyAIProfile
extends Resource

const BEHAVIOR_RANDOM_WEIGHTED := "RandomWeighted"

@export_enum("RandomWeighted") var behavior_mode: String = BEHAVIOR_RANDOM_WEIGHTED
@export var moves: Array[EnemyMoveData] = []
