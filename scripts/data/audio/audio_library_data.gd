class_name AudioLibraryData
extends Resource

@export var cues: Array[Resource] = []
@export var music_tracks: Array[Resource] = []

func get_cue(cue_id: StringName) -> Resource:
	for cue in cues:
		if cue != null and cue.id == cue_id:
			return cue

	return null

func get_music_track(track_id: StringName) -> Resource:
	for track in music_tracks:
		if track != null and track.id == track_id:
			return track

	return null
