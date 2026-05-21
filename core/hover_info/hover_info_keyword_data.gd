## Authored keyword entry for non-status hover explanations.
class_name HoverInfoKeywordData
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")

@export var id: StringName = &""
@export var aliases: Array[StringName] = []
@export var category: StringName = &"mechanic"
@export var display_name: String = ""
@export var subtitle: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var keyword_color: Color = Color(0.88, 0.76, 0.42, 1.0)
@export var tags: Array[StringName] = []
@export var panel_style: StringName = &"keyword"

func matches(keyword_id: StringName) -> bool:
	var normalized_id := normalized_keyword_id(keyword_id)
	if normalized_id.is_empty():
		return false
	if normalized_keyword_id(id) == normalized_id:
		return true

	for alias in aliases:
		if normalized_keyword_id(alias) == normalized_id:
			return true

	return false

func get_hover_info() -> Resource:
	var info := HoverInfoDataScript.new()
	info.icon = icon
	info.title = _resolved_display_name()
	info.subtitle = _resolved_subtitle()
	info.description = description.strip_edges()
	if category != &"":
		info.tags.append(category)
	info.tags.append_array(tags)
	info.panel_style = panel_style
	info.use_accent_color = true
	info.accent_color = keyword_color
	return info

func canonical_id() -> String:
	return normalized_keyword_id(id)

func _resolved_display_name() -> String:
	var trimmed_name := display_name.strip_edges()
	if not trimmed_name.is_empty():
		return trimmed_name

	var normalized_id := normalized_keyword_id(id)
	if normalized_id.contains("."):
		normalized_id = normalized_id.get_slice(".", normalized_id.split(".", false).size() - 1)
	return normalized_id.capitalize()

func _resolved_subtitle() -> String:
	var trimmed_subtitle := subtitle.strip_edges()
	if not trimmed_subtitle.is_empty():
		return trimmed_subtitle

	match category:
		&"class_resource":
			return "Class Resource"
		&"resource":
			return "Resource"
		&"status":
			return "Status"
		&"mechanic":
			return "Mechanic"
		_:
			return String(category).replace("_", " ").capitalize()

static func normalized_keyword_id(keyword_id: StringName) -> String:
	return String(keyword_id).strip_edges().to_lower()
