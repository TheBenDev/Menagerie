## Resource definition for a run-owned class passive and its authored hover text.
class_name ClassPassiveData
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const ClassRarityScript := preload("res://core/combat/classes/class_rarity.gd")

@export var id: StringName = &""
@export var display_name: String = "Passive"
@export_multiline var description: String = ""
@export var rarity: StringName = ClassRarityScript.UNCOMMON
@export var tags: Array[StringName] = []
@export var hover_keywords: Array[StringName] = []
@export var hover_fields: Array[Resource] = []
@export var hover_footer: String = ""

func get_hover_info() -> Resource:
	var info := HoverInfoDataScript.new()
	info.title = display_name.strip_edges()
	info.subtitle = "Passive"
	info.description = description.strip_edges()
	info.rarity = rarity
	info.tags.append_array(tags)
	info.keyword_ids.append_array(hover_keywords)
	info.fields.append_array(hover_fields)
	info.footer = hover_footer.strip_edges()
	info.panel_style = &"class_passive"
	return info
