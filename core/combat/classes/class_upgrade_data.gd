## Resource definition for a class upgrade that can be offered as a run reward.
class_name ClassUpgradeData
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const ClassRarityScript := preload("res://core/combat/classes/class_rarity.gd")

@export var id: StringName = &""
@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
@export var rarity: StringName = ClassRarityScript.UNCOMMON
@export var tags: Array[StringName] = []
@export var target_skill_id: StringName = &""
@export var target_stance_id: StringName = &""
@export var modifiers: Array[Dictionary] = []
@export var hover_keywords: Array[StringName] = []

func get_hover_info() -> Resource:
	var info := HoverInfoDataScript.new()
	info.title = display_name.strip_edges()
	info.subtitle = "Upgrade"
	info.description = description.strip_edges()
	info.rarity = rarity
	info.tags.append_array(tags)
	info.keyword_ids.append_array(hover_keywords)
	info.panel_style = &"class_upgrade"
	return info
