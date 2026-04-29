## Resource describing a sound cue, its candidate streams, mixer bus, pitch, cooldown, and priority.
class_name AudioCueData
extends Resource

@export var id: StringName = &""
@export var stream_ids: Array[StringName] = []
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var volume_db: float = 0.0
@export var pitch_min: float = 1.0
@export var pitch_max: float = 1.0
@export var cooldown_seconds: float = 0.0
@export var max_instances: int = 8
@export var priority: int = 0
