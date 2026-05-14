## Resource definition for a class-agnostic ability shown on the dungeon map hotbar.
class_name DungeonAbilityData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Dungeon Ability"
@export var hotbar_label: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var enabled: bool = true

func label_text() -> String:
	var trimmed_label := hotbar_label.strip_edges()
	if not trimmed_label.is_empty():
		return trimmed_label

	var trimmed_name := display_name.strip_edges()
	if not trimmed_name.is_empty():
		return trimmed_name.substr(0, 1).to_upper()

	return "?"
