## Resolves hover keyword ids to existing status resources for keyword side panels.
class_name HoverInfoKeywordResolver
extends RefCounted

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const STATUS_ROOT_PATH := "res://core/statuses"
const STATUS_NAMESPACE_PREFIX := "status."

static func keyword_infos_for_ids(keyword_ids: Array[StringName]) -> Array[Resource]:
	var infos: Array[Resource] = []
	var seen_ids: Dictionary = {}
	for keyword_id in keyword_ids:
		var normalized_id := _normalized_status_id(keyword_id)
		if normalized_id.is_empty() or seen_ids.has(normalized_id):
			continue

		seen_ids[normalized_id] = true
		var info := keyword_info_for_id(StringName(normalized_id))
		if info != null:
			infos.append(info)

	return infos

static func keyword_info_for_id(keyword_id: StringName) -> Resource:
	var status_path := status_path_for_id(keyword_id)
	if status_path.is_empty():
		return null

	var status_data := load(status_path) as Resource
	if status_data == null:
		push_warning("Hover keyword status could not be loaded from %s." % status_path)
		return null

	if status_data.has_method("get_hover_info"):
		var info = status_data.call("get_hover_info")
		if info != null:
			info.set("panel_style", &"keyword")
			return info

	var fallback_info := HoverInfoDataScript.new()
	fallback_info.title = str(status_data.get("display_name")).strip_edges()
	fallback_info.description = str(status_data.get("description")).strip_edges()
	fallback_info.panel_style = &"keyword"
	return fallback_info

static func status_path_for_id(status_id: StringName) -> String:
	var normalized_id := _normalized_status_id(status_id)
	if normalized_id.is_empty():
		return ""
	if normalized_id.begins_with("res://"):
		return normalized_id

	var segments := normalized_id.split(".", false)
	if segments.is_empty():
		return ""

	return STATUS_ROOT_PATH.path_join("/".join(segments)) + ".tres"

static func _normalized_status_id(status_id: StringName) -> String:
	var status_ref := String(status_id).strip_edges()
	if status_ref.is_empty():
		return ""
	if status_ref.begins_with(STATUS_NAMESPACE_PREFIX):
		return status_ref.substr(STATUS_NAMESPACE_PREFIX.length())

	return status_ref
