## Resource defining a timed status and its outgoing or incoming damage multipliers.
class_name StatusData
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")

@export var id: String = ""
@export var display_name: String = "Status"
@export_multiline var description: String = ""
@export var icon_atlas_coords: Vector2i = Vector2i(-1, -1)
@export var icon_atlas_cell_size: Vector2i = Vector2i(200, 200)
@export var duration_seconds: float = 0.0
@export var keyword_color: Color = Color(0.88, 0.76, 0.42, 1.0)

@export var outgoing_damage_multiplier: float = 1.0
@export var incoming_damage_multiplier: float = 1.0

func get_hover_info(remaining_seconds: float = -1.0) -> Resource:
	var info := HoverInfoDataScript.new()
	info.title = display_name
	info.description = description
	info.panel_style = &"status"
	info.use_accent_color = true
	info.accent_color = keyword_color

	if remaining_seconds > 0.0:
		info.add_field("Remaining", "%ss" % CombatTime.format_seconds(remaining_seconds))
	elif duration_seconds > 0.0:
		info.add_field("Duration", "%ss" % CombatTime.format_seconds(duration_seconds))

	if not is_equal_approx(outgoing_damage_multiplier, 1.0):
		info.add_field("Outgoing Damage", _multiplier_text(outgoing_damage_multiplier))
	if not is_equal_approx(incoming_damage_multiplier, 1.0):
		info.add_field("Incoming Damage", _multiplier_text(incoming_damage_multiplier))

	return info

func _multiplier_text(multiplier: float) -> String:
	var percent_delta := int(round((multiplier - 1.0) * 100.0))
	if percent_delta > 0:
		return "+%s%%" % percent_delta
	if percent_delta < 0:
		return "%s%%" % percent_delta

	return "No change"
