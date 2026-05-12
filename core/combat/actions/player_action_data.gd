## Player-only combat action data with rage cost, stance requirement, action bar visibility, and tooltip text.
class_name PlayerActionData
extends "res://core/combat/actions/combat_action_data.gd"

## Reserved for future class resources; current action resolution intentionally does not spend rage.
@export var rage_cost: int = 0
## Reserved for future class stance modes; current action selection intentionally ignores stance.
@export var required_stance: String = ""
## Reserved for future action bar filtering; current action bars show all profile actions.
@export var appears_on_action_bar: bool = true
@export_multiline var tooltip_text: String = ""
