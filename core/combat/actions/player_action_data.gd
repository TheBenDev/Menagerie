## Player-only combat action data with class resource costs, stance requirements, class skill metadata, and tooltip text.
class_name PlayerActionData
extends "res://core/combat/actions/combat_action_data.gd"

const ClassRarityScript := preload("res://core/combat/classes/class_rarity.gd")

## Resource costs spent by ActionCostService before the action is queued, keyed by class resource id.
@export var resource_costs: Dictionary = {}
## Required active class stance before the action can be queued.
@export var required_stance: String = ""
## Allows authored player actions to opt out of flat action bar fallback registries.
@export var appears_on_action_bar: bool = true
@export_multiline var tooltip_text: String = ""

@export_group("Class Skill")
@export var class_skill_id: StringName = &""
@export var skill_rarity: StringName = ClassRarityScript.COMMON
@export var skill_tags: Array[StringName] = []
@export var valid_as_stance_skill: bool = true
@export var valid_as_flex_skill: bool = true
@export var stance_id: StringName = &""

func is_class_skill() -> bool:
	return class_skill_id != &""
