## Runtime dungeon node state used by DungeonController to track grid placement, visits, reveal state, and connections.
class_name DungeonNodeData
extends RefCounted

const TYPE_EMPTY := "Empty"
const TYPE_HAVEN := "Haven"
const TYPE_FIGHT := "Fight"
const TYPE_ENCOUNTER := "Encounter"
const TYPE_BOSS := "Boss"

var id: int = -1
var node_type: String = TYPE_FIGHT
var grid_position: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var visited: bool = false
var revealed: bool = false
var resolved: bool = false
var connected_node_ids: Array[int] = []
var enemy_profile: String = ""
var encounter_id: StringName = &""
var is_boss: bool = false

func _init(
	new_id: int = -1,
	new_node_type: String = TYPE_FIGHT,
	new_enemy_profile: String = "",
	new_encounter_id: StringName = &"",
	new_is_boss: bool = false,
	new_grid_position: Vector2i = Vector2i.ZERO,
	new_grid_size: Vector2i = Vector2i.ONE
) -> void:
	id = new_id
	node_type = new_node_type
	enemy_profile = new_enemy_profile
	encounter_id = new_encounter_id
	is_boss = new_is_boss
	grid_position = new_grid_position
	grid_size = new_grid_size
