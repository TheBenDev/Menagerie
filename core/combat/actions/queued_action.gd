## Represents an action waiting on the combat timeline, including status, resolve timing, and tie-break data.
class_name QueuedAction
extends RefCounted

const STATUS_PENDING := "pending"
const STATUS_RESOLVED := "resolved"
const STATUS_CANCELLED := "cancelled"

var id: int = 0
var actor: Combatant
var action: CombatActionData
var resolve_time: float = 0.0
var status: String = STATUS_PENDING
var resolved_time: float = -1.0
var resolution_order: int = -1
var tie_rolls: Array[int] = []

func _init(
	_id: int,
	_actor: Combatant,
	_action: CombatActionData,
	_resolve_time: float
) -> void:
	id = _id
	actor = _actor
	action = _action
	resolve_time = _resolve_time

func is_pending() -> bool:
	return status == STATUS_PENDING
