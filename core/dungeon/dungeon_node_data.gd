## Runtime dungeon node state used by DungeonController to track visited, revealed, and connected nodes.
class_name DungeonNodeData
extends RefCounted

const TYPE_HAVEN := "Haven"
const TYPE_FIGHT := "Fight"
const TYPE_BOSS := "Boss"

var id: int = -1
var node_type: String = TYPE_FIGHT
var visited: bool = false
var revealed: bool = false
var connected_node_ids: Array[int] = []
var enemy_profile: String = ""
var is_boss: bool = false

func _init(
	new_id: int = -1,
	new_node_type: String = TYPE_FIGHT,
	new_enemy_profile: String = "",
	new_is_boss: bool = false
) -> void:
	id = new_id
	node_type = new_node_type
	enemy_profile = new_enemy_profile
	is_boss = new_is_boss
