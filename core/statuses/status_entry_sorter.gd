## Sort helper for status-entry dictionaries shown by combat HUD widgets.
class_name StatusEntrySorter
extends RefCounted

static func sort_entries(entries: Array) -> void:
	entries.sort_custom(by_display_name)

static func by_display_name(a: Dictionary, b: Dictionary) -> bool:
	var a_name: String = str(a.get("display_name", ""))
	var b_name: String = str(b.get("display_name", ""))
	return a_name.naturalnocasecmp_to(b_name) < 0
