## Resource definition for a combat action, including timing, costs, effect data, audio, and target side.
class_name CombatActionData
extends Resource

@export var id: String = ""
@export var display_name: String = "Action"
@export_multiline var description: String = ""

@export var effect_data: Array[Dictionary] = []

@export var start_sfx_id: StringName = &""
@export var resolve_sfx_id: StringName = &""

@export var time_cost: float = 5.0
@export var hp_cost: int = 0
;# Reserved for future mana users; current resolution intentionally does not spend mana.
@export var mana_cost: int = 0

@export var target_enemy: bool = true
