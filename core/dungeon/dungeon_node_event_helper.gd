## Shared builder for dungeon node visit event payloads.
class_name DungeonNodeEventHelper
extends RefCounted

const EVENT_NODE_ID := "node_id"
const EVENT_NODE_TYPE := "node_type"
const EVENT_ENEMY_PROFILE := "enemy_profile"
const EVENT_ENCOUNTER_ID := "encounter_id"
const EVENT_COMBAT_ENCOUNTER_ID := "combat_encounter_id"
const EVENT_COMBAT_ENCOUNTER_PROFILE_PATH := "combat_encounter_profile_path"
const EVENT_IS_BOSS := "is_boss"

static func build_node_event(node: DungeonNodeData) -> Dictionary:
	if node == null:
		return {}

	return {
		EVENT_NODE_ID: node.id,
		EVENT_NODE_TYPE: node.node_type,
		EVENT_ENEMY_PROFILE: node.enemy_profile,
		EVENT_ENCOUNTER_ID: node.encounter_id,
		EVENT_COMBAT_ENCOUNTER_ID: node.combat_encounter_id,
		EVENT_COMBAT_ENCOUNTER_PROFILE_PATH: node.combat_encounter_profile_path,
		EVENT_IS_BOSS: node.is_boss,
	}
