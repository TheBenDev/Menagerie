## Autoload service that owns the active difficulty ID and validated difficulty profile lookup.
extends Node

const DEFAULT_DIFFICULTY_ID := &"normal"
const PROFILE_PATHS := {
	&"easy": "res://core/difficulty/easy.tres",
	&"normal": "res://core/difficulty/normal.tres",
	&"hard": "res://core/difficulty/hard.tres",
}

var _active_difficulty_id: StringName = DEFAULT_DIFFICULTY_ID

## Sets the active difficulty for new runtime requests after validating the authored profile exists.
func set_active_difficulty_id(difficulty_id: StringName) -> void:
	validate_difficulty_id(difficulty_id)
	if not _has_difficulty_id(difficulty_id):
		return

	_active_difficulty_id = difficulty_id

func get_active_difficulty_id() -> StringName:
	return _active_difficulty_id

func get_active_profile() -> Resource:
	return get_profile(_active_difficulty_id)

func get_profile(difficulty_id: StringName) -> Resource:
	validate_difficulty_id(difficulty_id)
	if not _has_difficulty_id(difficulty_id):
		return null

	var profile_path := str(PROFILE_PATHS[difficulty_id])
	var profile := load(profile_path) as Resource
	if profile == null:
		push_error("Difficulty profile %s could not be loaded from %s." % [difficulty_id, profile_path])
	return profile

func validate_difficulty_id(difficulty_id: StringName) -> void:
	if _has_difficulty_id(difficulty_id):
		return

	push_error("Unknown difficulty id: %s." % difficulty_id)

func get_profile_path(difficulty_id: StringName) -> String:
	validate_difficulty_id(difficulty_id)
	if not _has_difficulty_id(difficulty_id):
		return ""

	return str(PROFILE_PATHS[difficulty_id])

func get_active_display_name() -> String:
	var profile := get_active_profile()
	if profile == null:
		return String(_active_difficulty_id).capitalize()

	return str(profile.get("display_name"))

func _has_difficulty_id(difficulty_id: StringName) -> bool:
	return PROFILE_PATHS.has(difficulty_id)
