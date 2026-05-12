## Resource configuration for drawing a combatant resource bar from a combatant resource snapshot.
class_name ResourceBarConfig
extends Resource

@export var resource_id: String = ""
@export var label: String = "Resource"
@export var reference_value: int = 1
@export var display_reference_value: bool = true
@export var low_color: Color = Color(0.86, 0.16, 0.12)
@export var high_color: Color = Color(0.16, 0.72, 0.26)
@export var over_reference_color: Color = Color.TRANSPARENT
@export var bonus_label: String = ""
