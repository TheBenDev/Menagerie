## Normalization helpers for authored and runtime hotbar slot entries.
class_name HotbarSlotSchema
extends RefCounted

static func slot_kind(entry: Dictionary) -> StringName:
	var value: Variant = entry.get("kind", &"empty")
	return value if value is StringName else StringName(str(value))

static func slot_id(entry: Dictionary) -> StringName:
	var value: Variant = entry.get("slot_id", &"")
	return value if value is StringName else StringName(str(value))

static func is_action(entry: Dictionary) -> bool:
	return slot_kind(entry) == &"action"

static func is_selectable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if entry.has("selectable") and not bool(entry.get("selectable", false)):
		return false
	return is_action(entry)
