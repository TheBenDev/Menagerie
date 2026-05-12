## Button that exposes static hover information for the fixed combat info panel.
@tool
class_name HoverInfoButton
extends Button

const HoverInfoPanelScript := preload("res://scenes/combat/ui/hover_info_panel.gd")

@export var hover_info_title: String = "":
	set(value):
		hover_info_title = value
		_refresh_hover_info()

@export_multiline var hover_info_description: String = "":
	set(value):
		hover_info_description = value
		_refresh_hover_info()

@export var hover_info_details: Array[String] = []:
	set(value):
		hover_info_details = value
		_refresh_hover_info()

func _ready() -> void:
	_refresh_hover_info()

func _refresh_hover_info() -> void:
	var title: String = hover_info_title.strip_edges()
	if title.is_empty():
		title = text.strip_edges()

	set_meta(HoverInfoPanelScript.META_TITLE, title)
	set_meta(HoverInfoPanelScript.META_DESCRIPTION, hover_info_description)
	set_meta(HoverInfoPanelScript.META_DETAILS, hover_info_details)
