## Structured label/value row for hover tooltip details.
class_name HoverInfoField
extends Resource

@export var label: String = ""
@export var value: String = ""
@export var icon: Texture2D = null

static func from_values(new_label: String, new_value: String, new_icon: Texture2D = null) -> Resource:
	var field := load("res://core/hover_info/hover_info_field.gd").new() as Resource
	field.set("label", new_label)
	field.set("value", new_value)
	field.set("icon", new_icon)
	return field
