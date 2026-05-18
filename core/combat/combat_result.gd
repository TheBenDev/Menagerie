## Summary of one combat instance used to update run progress, rewards, participants, and summary UI.
class_name CombatResult
extends RefCounted

const SIDE_ID_PLAYER := "player"
const SIDE_ID_ENEMY := "enemy"

const PARTICIPANT_COMBATANT_ID := "combatant_id"
const PARTICIPANT_SIDE_ID := "side_id"
const PARTICIPANT_NODE_NAME := "node_name"
const PARTICIPANT_PROFILE_PATH := "profile_path"
const PARTICIPANT_HP_BEFORE := "hp_before"
const PARTICIPANT_HP_AFTER := "hp_after"
const PARTICIPANT_MAX_HP := "max_hp"
const PARTICIPANT_DEFEATED := "defeated"

var combat_instance_id: String = ""
var victory: bool = false
var node_id: int = -1
var is_boss: bool = false
var winning_side_id: String = ""
var defeated_side_ids: Array[String] = []
var participant_results: Array[Dictionary] = []

var damage_dealt: int = 0
var damage_taken: int = 0
var actions_used: int = 0
var time_elapsed: float = 0.0
var memories_awarded: int = 0
var gold_awarded: int = 0
var end_reason: String = ""
