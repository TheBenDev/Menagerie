## Resource describing an adaptive music variant for a named state, including stream and fade behavior.
class_name MusicStateData
extends Resource

@export var state_id: StringName = &""
@export var stream_id: StringName = &""
@export var stream: AudioStream = null
@export var fade_seconds: float = -1.0
@export var min_hold_seconds: float = 1.0
