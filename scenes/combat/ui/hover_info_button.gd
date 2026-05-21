## Button that exposes static hover tooltip data to the dynamic tooltip layer.
@tool
class_name HoverInfoButton
extends Button

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")

@export var info_title: String = ""
@export_multiline var info_description: String = ""
@export var info_keywords: Array[StringName] = []
@export var info_fields: Array[Resource] = []
@export var info_footer: String = ""
@export var panel_style: StringName = &"ui"

func _ready() -> void:
	tooltip_text = ""

func get_hover_info() -> Resource:
	var info := HoverInfoDataScript.new()
	info.title = info_title.strip_edges()
	if info.title.is_empty():
		info.title = text.strip_edges()
	info.description = info_description.strip_edges()
	info.keyword_ids.append_array(info_keywords)
	info.fields.append_array(info_fields)
	info.footer = info_footer.strip_edges()
	info.panel_style = panel_style
	return info
