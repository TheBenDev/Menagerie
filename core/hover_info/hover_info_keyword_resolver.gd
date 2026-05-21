## Resolves hover keyword ids through authored keywords and existing status resources.
class_name HoverInfoKeywordResolver
extends RefCounted

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const DEFAULT_KEYWORD_REGISTRY_PATH := "res://core/hover_info/default_hover_keyword_registry.tres"
const STATUS_ROOT_PATH := "res://core/statuses"
const STATUS_NAMESPACE_PREFIX := "status."

static func keyword_infos_for_ids(keyword_ids: Array[StringName]) -> Array[Resource]:
	var infos: Array[Resource] = []
	var seen_ids: Dictionary = {}
	for keyword_id in keyword_ids:
		var dedupe_id := _dedupe_id_for_keyword(keyword_id)
		if dedupe_id.is_empty() or seen_ids.has(dedupe_id):
			continue

		seen_ids[dedupe_id] = true
		var info := keyword_info_for_id(keyword_id)
		if info != null:
			infos.append(info)

	return infos

static func keyword_info_for_id(keyword_id: StringName) -> Resource:
	var registry_info := _registry_keyword_info_for_id(keyword_id)
	if registry_info != null:
		registry_info.set("panel_style", &"keyword")
		return registry_info

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

static func keyword_color_for_id(keyword_id: StringName, fallback_color: Color = Color.WHITE) -> Color:
	var info := keyword_info_for_id(keyword_id)
	if info != null and bool(info.get("use_accent_color")):
		var accent_color: Variant = info.get("accent_color")
		if accent_color is Color:
			return accent_color

	return fallback_color

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

static func _registry_keyword_info_for_id(keyword_id: StringName) -> Resource:
	var registry := _default_keyword_registry()
	if registry == null or not registry.has_method("keyword_info_for_id"):
		return null

	return registry.call("keyword_info_for_id", keyword_id) as Resource

static func _default_keyword_registry() -> Resource:
	if not ResourceLoader.exists(DEFAULT_KEYWORD_REGISTRY_PATH):
		return null

	var registry := load(DEFAULT_KEYWORD_REGISTRY_PATH) as Resource
	if registry == null:
		push_warning("Hover keyword registry could not be loaded from %s." % DEFAULT_KEYWORD_REGISTRY_PATH)
	return registry

static func _dedupe_id_for_keyword(keyword_id: StringName) -> String:
	var registry := _default_keyword_registry()
	if registry != null and registry.has_method("canonical_id_for_id"):
		var registry_id := str(registry.call("canonical_id_for_id", keyword_id)).strip_edges()
		if not registry_id.is_empty():
			return "registry:%s" % registry_id

	var status_id := _normalized_status_id(keyword_id)
	if not status_id.is_empty():
		return "status:%s" % status_id

	return ""

static func _normalized_status_id(status_id: StringName) -> String:
	var status_ref := String(status_id).strip_edges()
	if status_ref.is_empty():
		return ""
	if status_ref.begins_with(STATUS_NAMESPACE_PREFIX):
		return status_ref.substr(STATUS_NAMESPACE_PREFIX.length())

	return status_ref
