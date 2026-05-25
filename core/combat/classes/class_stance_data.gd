## Shared class stance definition for stance hotbar entries, Strike replacement, entry effects, and fixed skills.
class_name ClassStanceData
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const ClassRarityScript := preload("res://core/combat/classes/class_rarity.gd")

@export var id: StringName = &""
@export var display_name: String = "Stance"
@export_multiline var description: String = ""
@export var unlock_rarity: StringName = ClassRarityScript.RARE
@export var tags: Array[StringName] = []
@export var strike_replacement_action_id: StringName = &""
@export var fixed_skill_ids: Array[StringName] = []
@export var entry_bonus_effect_data: Array[Dictionary] = []
@export var switch_time_cost: float = 1.0
@export_multiline var switch_description: String = ""
@export var hover_keywords: Array[StringName] = []

func validate() -> String:
	if id == &"":
		return "ClassStanceData is missing id."
	if not ClassRarityScript.is_valid(unlock_rarity):
		return "ClassStanceData %s has invalid unlock_rarity %s." % [id, unlock_rarity]
	if strike_replacement_action_id == &"":
		return "ClassStanceData %s is missing strike_replacement_action_id." % id
	if fixed_skill_ids.is_empty():
		return "ClassStanceData %s is missing fixed_skill_ids." % id
	if switch_time_cost <= 0.0:
		return "ClassStanceData %s must have a positive switch_time_cost." % id
	return ""

func label_text() -> String:
	var resolved_name := display_name.strip_edges()
	if resolved_name.is_empty():
		return "?"
	return resolved_name.substr(0, 1).to_upper()

func resolved_switch_description() -> String:
	var authored_description := switch_description.strip_edges()
	if not authored_description.is_empty():
		return authored_description
	return "Enter %s stance." % display_name.strip_edges()

func get_hover_info() -> Resource:
	var info := HoverInfoDataScript.new()
	info.title = display_name.strip_edges()
	info.subtitle = "Stance"
	info.description = description.strip_edges()
	info.rarity = unlock_rarity
	info.tags.append_array(tags)
	info.keyword_ids.append_array(hover_keywords)
	info.panel_style = &"stance"
	return info
