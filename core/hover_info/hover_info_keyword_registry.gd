## Resource index for keyword entries that are not backed by status resources.
class_name HoverInfoKeywordRegistry
extends Resource

@export var keywords: Array[Resource] = []

func keyword_info_for_id(keyword_id: StringName) -> Resource:
	var entry := keyword_entry_for_id(keyword_id)
	if entry == null:
		return null

	if entry.has_method("get_hover_info"):
		return entry.call("get_hover_info") as Resource

	return null

func canonical_id_for_id(keyword_id: StringName) -> String:
	var entry := keyword_entry_for_id(keyword_id)
	if entry == null:
		return ""
	if entry.has_method("canonical_id"):
		return str(entry.call("canonical_id"))

	var entry_id := str(entry.get("id")).strip_edges().to_lower()
	return entry_id

func keyword_entry_for_id(keyword_id: StringName) -> Resource:
	for entry in keywords:
		if entry == null:
			continue
		if entry.has_method("matches") and bool(entry.call("matches", keyword_id)):
			return entry

	return null
