## Scene route helper for resolving scene references and validating scene paths.
class_name SceneRouteService
extends RefCounted

const SCENE_ROOT_PATH := "res://scenes"
const SCENE_EXTENSION := ".tscn"

const SCENE_ROUTE_PATHS := {
	"main_menu": "ui/main_menu/MainMenu",
	"waiting_room": "ui/waiting_room/WaitingRoom",
	"run_summary": "ui/run_summary/RunSummary",
	"dungeon": "dungeon/DungeonMap",
}

static func scene_path_for(scene_ref: String) -> String:
	var normalized_ref := scene_ref.strip_edges().replace("\\", "/")
	if normalized_ref.is_empty():
		return ""

	if normalized_ref.begins_with("res://"):
		return with_scene_extension(normalized_ref)

	normalized_ref = normalized_ref.trim_prefix("/")
	if normalized_ref.begins_with("scenes/"):
		normalized_ref = normalized_ref.substr("scenes/".length())
	normalized_ref = scene_route_path_for(normalized_ref)

	return with_scene_extension(SCENE_ROOT_PATH.path_join(normalized_ref))

static func scene_route_path_for(scene_ref: String) -> String:
	var route_key := scene_ref
	if route_key.ends_with(SCENE_EXTENSION):
		route_key = route_key.substr(0, route_key.length() - SCENE_EXTENSION.length())

	return str(SCENE_ROUTE_PATHS.get(route_key, scene_ref))

static func with_scene_extension(scene_path: String) -> String:
	if scene_path.ends_with(SCENE_EXTENSION):
		return scene_path
	if scene_path.get_extension().is_empty():
		return scene_path + SCENE_EXTENSION

	return scene_path
