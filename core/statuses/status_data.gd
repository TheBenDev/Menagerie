## Resource defining a timed status and its outgoing or incoming damage multipliers.
class_name StatusData
extends Resource

@export var id: String = ""
@export var display_name: String = "Status"
@export_multiline var description: String = ""
@export var icon_atlas_coords: Vector2i = Vector2i(-1, -1)
@export var icon_atlas_cell_size: Vector2i = Vector2i(200, 200)
@export var duration_seconds: float = 0.0

@export var outgoing_damage_multiplier: float = 1.0
@export var incoming_damage_multiplier: float = 1.0
