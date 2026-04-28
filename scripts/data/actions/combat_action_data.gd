class_name CombatActionData
extends Resource

@export var id: String = ""
@export var display_name: String = "Action"

@export var time_cost: float = 5.0

@export var effects: Array[ActionEffect] = []

@export var start_sfx_id: StringName = &""
@export var resolve_sfx_id: StringName = &""

@export var hp_cost: int = 0
@export var mana_cost: int = 0

@export var target_enemy: bool = true
