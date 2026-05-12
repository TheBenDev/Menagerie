## Shared dispatcher for dungeon node visit events and existing route handoffs.
class_name DungeonNodeEventHelper
extends RefCounted

const EVENT_NODE_ID := "node_id"
const EVENT_NODE_TYPE := "node_type"
const EVENT_ENEMY_PROFILE := "enemy_profile"
const EVENT_IS_BOSS := "is_boss"
const RESULT_EVENT := "event"
const RESULT_COMPLETION_DEFERRED := "completion_deferred"
const RESULT_HANDLED := "handled"

static func build_node_event(node: DungeonNodeData) -> Dictionary:
	if node == null:
		return {}

	return {
		EVENT_NODE_ID: node.id,
		EVENT_NODE_TYPE: node.node_type,
		EVENT_ENEMY_PROFILE: node.enemy_profile,
		EVENT_IS_BOSS: node.is_boss,
	}

static func process_node_event(node: DungeonNodeData, game_manager: Node, sound_manager: Node = null) -> Dictionary:
	var event := build_node_event(node)
	var handled := false
	var completion_deferred := false
	if node == null:
		return {
			RESULT_EVENT: event,
			RESULT_HANDLED: handled,
			RESULT_COMPLETION_DEFERRED: completion_deferred,
		}

	match node.node_type:
		DungeonNodeData.TYPE_FIGHT, DungeonNodeData.TYPE_BOSS:
			handled = true
			completion_deferred = true
			if (node.is_boss or node.node_type == DungeonNodeData.TYPE_BOSS) and sound_manager != null:
				sound_manager.call("play_sfx", &"sfx.global.boss.boss_start_fight")
			if game_manager != null:
				game_manager.call("start_combat", node.id, node.node_type, node.enemy_profile, node.is_boss)

	return {
		RESULT_EVENT: event,
		RESULT_HANDLED: handled,
		RESULT_COMPLETION_DEFERRED: completion_deferred,
	}
