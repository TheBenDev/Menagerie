class_name MusicTrackData
extends Resource

@export var id: StringName = &""
@export var base_stream: AudioStream = null
@export var playlist_streams: Array[AudioStream] = []
@export var randomize_playlist: bool = false
@export var avoid_immediate_repeats: bool = true
@export var playlist_crossfade_min_seconds: float = 5.0
@export var playlist_crossfade_max_seconds: float = 10.0
@export var state_variants: Array[Resource] = []
@export var bus: StringName = &"Music"
@export var volume_db: float = 0.0
@export var default_fade_seconds: float = 0.75
@export var loop: bool = true

func get_state_variant(state_id: StringName) -> Resource:
	for variant in state_variants:
		if variant != null and variant.state_id == state_id:
			return variant

	return null
