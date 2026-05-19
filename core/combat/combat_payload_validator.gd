## Validates generated dungeon combat payloads before they are used by managers and scenes.
class_name CombatPayloadValidator
extends RefCounted

const FIELD_NODE_ID := "node_id"
const FIELD_COMBAT_ENCOUNTER_ID := "combat_encounter_id"
const FIELD_ENEMY_INSTANCES := "enemy_instances"
const FIELD_ENEMY_INSTANCE_ID := "instance_id"
const FIELD_ENEMY_PROFILE_PATH := "profile_path"
const FIELD_ENEMY_SLOT_ID := "slot_id"
const FIELD_ENEMY_LEVEL := "level"
const FIELD_ENEMY_STAT_SEED := "stat_seed"

static func is_valid_enemy_instance(instance: Dictionary) -> bool:
	return enemy_instance_error(instance).is_empty()

static func enemy_instance_error(instance: Dictionary) -> String:
	if String(instance.get(FIELD_ENEMY_INSTANCE_ID, "")).strip_edges().is_empty():
		return "missing enemy instance_id"
	if String(instance.get(FIELD_ENEMY_PROFILE_PATH, "")).strip_edges().is_empty():
		return "missing enemy profile_path"
	if String(instance.get(FIELD_ENEMY_SLOT_ID, "")).strip_edges().is_empty():
		return "missing enemy slot_id"
	if not instance.has(FIELD_ENEMY_LEVEL):
		return "missing enemy level"
	if not (typeof(instance.get(FIELD_ENEMY_LEVEL)) == TYPE_INT):
		return "enemy level must be integer"
	if not instance.has(FIELD_ENEMY_STAT_SEED):
		return "missing enemy stat_seed"
	if not (typeof(instance.get(FIELD_ENEMY_STAT_SEED)) == TYPE_INT):
		return "enemy stat_seed must be integer"

	return ""

static func is_valid_combat_payload(payload: Dictionary) -> bool:
	return combat_payload_error(payload).is_empty()

static func combat_payload_error(payload: Dictionary) -> String:
	if not payload.has(FIELD_NODE_ID):
		return "invalid node_id"
	if not (typeof(payload.get(FIELD_NODE_ID)) == TYPE_INT):
		return "node_id must be integer"
	if int(payload.get(FIELD_NODE_ID, -1)) < 0:
		return "invalid node_id"
	if String(payload.get(FIELD_COMBAT_ENCOUNTER_ID, "")).strip_edges().is_empty():
		return "missing combat_encounter_id"

	var enemy_instances: Variant = payload.get(FIELD_ENEMY_INSTANCES, [])
	if not (enemy_instances is Array):
		return "enemy_instances must be an array"
	if enemy_instances.is_empty():
		return "missing enemy_instances"

	for raw_instance in enemy_instances:
		if not (raw_instance is Dictionary):
			return "enemy_instances contains a non-dictionary value"
		var instance: Dictionary = raw_instance
		var instance_error := enemy_instance_error(instance)
		if not instance_error.is_empty():
			return instance_error

	return ""
