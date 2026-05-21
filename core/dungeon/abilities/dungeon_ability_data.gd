## Resource definition for a class-agnostic ability shown on the dungeon map hotbar.
class_name DungeonAbilityData
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")

@export var id: StringName = &""
@export var display_name: String = "Dungeon Ability"
@export var hotbar_label: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var enabled: bool = true

@export_group("Hover Info")
@export var show_hover_info: bool = true
@export var hover_keywords: Array[StringName] = []
@export var hover_fields: Array[Resource] = []
@export var hover_footer: String = ""

func label_text() -> String:
	var trimmed_label := hotbar_label.strip_edges()
	if not trimmed_label.is_empty():
		return trimmed_label

	var trimmed_name := display_name.strip_edges()
	if not trimmed_name.is_empty():
		return trimmed_name.substr(0, 1).to_upper()

	return "?"

func get_hover_info() -> Resource:
	if not show_hover_info:
		return null

	var info := HoverInfoDataScript.new()
	info.icon = icon
	info.title = display_name.strip_edges()
	info.description = description.strip_edges()
	info.keyword_ids.append_array(hover_keywords)
	info.fields.append_array(hover_fields)
	info.footer = hover_footer.strip_edges()
	info.panel_style = &"dungeon_ability"
	return info if info.has_content() else null
