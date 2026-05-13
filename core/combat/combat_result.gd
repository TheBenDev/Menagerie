## Summary of one encounter result used to update run progress, rewards, and the run summary screen.
class_name CombatResult
extends RefCounted

var victory: bool = false
var node_id: int = -1
var is_boss: bool = false

var damage_dealt: int = 0
var damage_taken: int = 0
var actions_used: int = 0
var time_elapsed: float = 0.0
var player_hp_before: int = 0
var player_hp_after: int = 0
var player_max_hp: int = 0
var memories_awarded: int = 0
var gold_awarded: int = 0
var end_reason: String = ""

var enemy_defeated: bool = false
var player_defeated: bool = false
