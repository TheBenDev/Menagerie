## Player-only combat action data with rage cost, stance requirement, action bar visibility, and tooltip text.
class_name PlayerActionData
extends "res://scripts/data/actions/combat_action_data.gd"

@export var rage_cost: int = 0
@export var required_stance: String = ""
@export var appears_on_action_bar: bool = true
@export_multiline var tooltip_text: String = ""
