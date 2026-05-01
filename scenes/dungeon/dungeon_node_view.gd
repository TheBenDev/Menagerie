## Button view for a dungeon node that displays availability, encounter type, and selection tooltip text.
class_name DungeonNodeView
extends Button

@export var node_id: int = -1
@export_enum("Haven", "Fight", "Boss") var node_type: String = "Fight"
@export_file("*.tres") var enemy_profile_path: String = ""
@export var is_boss: bool = false

func apply_state(data: Variant, is_current: bool, can_select: bool) -> void:
	if data == null:
		text = "?"
		disabled = true
		return

	if not data.revealed and not data.visited:
		text = "?\nHidden"
	elif data.visited and is_current:
		text = "Current\n%s" % data.node_type
	elif data.visited:
		text = "Visited\n%s" % data.node_type
	else:
		text = "%s\nRevealed" % data.node_type

	disabled = not can_select
	tooltip_text = _tooltip_for(data, is_current, can_select)

func _tooltip_for(data: Variant, is_current: bool, can_select: bool) -> String:
	if not data.revealed and not data.visited:
		return "Hidden"
	if is_current:
		return "Current location"
	if data.visited:
		return "Visited"
	if can_select:
		return "Enter %s" % data.node_type

	return "Not reachable yet"
