class_name AudioRegistry
extends RefCounted

const DEFAULT_ROOT_PATH := "res://sounds"
const SUPPORTED_EXTENSIONS := {
	"wav": true,
	"ogg": true,
	"mp3": true,
}

var streams_by_id: Dictionary = {}
var paths_by_id: Dictionary = {}
var ids_by_path: Dictionary = {}
var duplicate_paths: Dictionary = {}
var failed_paths: Array[String] = []

func scan(root_path: String = DEFAULT_ROOT_PATH) -> void:
	streams_by_id.clear()
	paths_by_id.clear()
	ids_by_path.clear()
	duplicate_paths.clear()
	failed_paths.clear()

	var audio_paths: Array[String] = []
	_collect_audio_paths(root_path, audio_paths)
	audio_paths.sort()

	for audio_path in audio_paths:
		var stream_id := stream_id_for_path(audio_path, root_path)
		if String(stream_id).is_empty():
			continue
		if streams_by_id.has(stream_id):
			if not duplicate_paths.has(stream_id):
				duplicate_paths[stream_id] = [paths_by_id.get(stream_id, "")]
			duplicate_paths[stream_id].append(audio_path)
			continue

		var stream := ResourceLoader.load(audio_path) as AudioStream
		if stream == null:
			failed_paths.append(audio_path)
			continue

		streams_by_id[stream_id] = stream
		paths_by_id[stream_id] = audio_path
		ids_by_path[audio_path] = stream_id

func has_stream(stream_id: StringName) -> bool:
	return streams_by_id.has(stream_id)

func get_stream(stream_id: StringName) -> AudioStream:
	return streams_by_id.get(stream_id, null) as AudioStream

func get_path(stream_id: StringName) -> String:
	return str(paths_by_id.get(stream_id, ""))

func get_stream_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw_id in streams_by_id.keys():
		ids.append(StringName(raw_id))
	ids.sort()
	return ids

func get_stream_count() -> int:
	return streams_by_id.size()

static func stream_id_for_path(audio_path: String, root_path: String = DEFAULT_ROOT_PATH) -> StringName:
	var normalized_root := root_path.trim_suffix("/")
	var relative_path := audio_path
	if relative_path.begins_with(normalized_root + "/"):
		relative_path = relative_path.substr(normalized_root.length() + 1)

	var extension := relative_path.get_extension()
	if not extension.is_empty():
		relative_path = relative_path.substr(0, relative_path.length() - extension.length() - 1)

	var normalized_segments: PackedStringArray = []
	for raw_segment in relative_path.split("/", false):
		var normalized_segment := normalize_segment(raw_segment)
		if not normalized_segment.is_empty():
			normalized_segments.append(normalized_segment)

	return StringName(".".join(normalized_segments))

static func normalize_segment(segment: String) -> String:
	var normalized := ""
	var previous_was_separator := false

	for index in range(segment.length()):
		var character := segment.substr(index, 1)
		var code := segment.unicode_at(index)
		var is_upper := code >= 65 and code <= 90
		var is_alphanumeric := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
		)
		if is_alphanumeric:
			if _should_insert_case_separator(segment, index) and not previous_was_separator and not normalized.is_empty():
				normalized += "_"
			normalized += character.to_lower() if is_upper else character
			previous_was_separator = false
		elif not previous_was_separator:
			normalized += "_"
			previous_was_separator = true

	return normalized.trim_prefix("_").trim_suffix("_")

static func _should_insert_case_separator(value: String, index: int) -> bool:
	var code := value.unicode_at(index)
	if code < 65 or code > 90 or index <= 0:
		return false

	var previous_code := value.unicode_at(index - 1)
	if (previous_code >= 97 and previous_code <= 122) or (previous_code >= 48 and previous_code <= 57):
		return true

	if previous_code >= 65 and previous_code <= 90 and index < value.length() - 1:
		var next_code := value.unicode_at(index + 1)
		return next_code >= 97 and next_code <= 122

	return false

func _collect_audio_paths(folder_path: String, audio_paths: Array[String]) -> void:
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name.begins_with("."):
			entry_name = directory.get_next()
			continue

		var entry_path := folder_path.path_join(entry_name)
		if directory.current_is_dir():
			_collect_audio_paths(entry_path, audio_paths)
		elif _is_supported_audio_file(entry_name):
			audio_paths.append(entry_path)

		entry_name = directory.get_next()

	directory.list_dir_end()

func _is_supported_audio_file(file_name: String) -> bool:
	var extension := file_name.get_extension().to_lower()
	return bool(SUPPORTED_EXTENSIONS.get(extension, false))
