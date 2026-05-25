## Resource definition for class-owned combat resources, gain rules, decay rules, labels, and hover styling.
class_name ClassResourceData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Resource"
@export var keyword_id: StringName = &""
@export var keyword_color: Color = Color(1.0, 0.82, 0.24, 1.0)
@export var starting_amount: int = 0
@export var reference_value: int = 100
@export var damage_dealt_gain_multiplier: float = 0.0
@export var damage_taken_gain_multiplier: float = 0.0
@export var decay_per_second: float = 0.0

func validate() -> String:
	if id == &"":
		return "ClassResourceData is missing id."
	if display_name.strip_edges().is_empty():
		return "ClassResourceData %s is missing display_name." % id
	if reference_value <= 0:
		return "ClassResourceData %s must have a positive reference_value." % id
	if starting_amount < 0:
		return "ClassResourceData %s cannot start below zero." % id
	if damage_dealt_gain_multiplier < 0.0:
		return "ClassResourceData %s cannot have negative damage_dealt_gain_multiplier." % id
	if damage_taken_gain_multiplier < 0.0:
		return "ClassResourceData %s cannot have negative damage_taken_gain_multiplier." % id
	if decay_per_second < 0.0:
		return "ClassResourceData %s cannot have negative decay_per_second." % id
	return ""

func resolved_keyword_id() -> StringName:
	if keyword_id != &"":
		return keyword_id
	return StringName("resource.%s" % String(id))

func damage_dealt_gain(amount: int) -> int:
	return _scaled_amount(amount, damage_dealt_gain_multiplier)

func damage_taken_gain(amount: int) -> int:
	return _scaled_amount(amount, damage_taken_gain_multiplier)

func _scaled_amount(amount: int, multiplier: float) -> int:
	if amount <= 0 or multiplier <= 0.0:
		return 0
	return max(int(floor(float(amount) * multiplier)), 0)

