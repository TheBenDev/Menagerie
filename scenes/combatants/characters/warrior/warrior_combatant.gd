## Player combatant that builds and decays rage from dealing or taking damage.
class_name WarriorCombatant
extends "res://scenes/combatants/combatant.gd"

signal rage_changed(combatant: WarriorCombatant)

var rage: int = 0
var rage_decay_accumulator: float = 0.0

func reset_runtime_state() -> void:
	super.reset_runtime_state()
	rage = 0
	rage_decay_accumulator = 0.0

func gain_rage(amount: int) -> void:
	if amount <= 0:
		return

	rage += amount
	rage_changed.emit(self)

func on_damage_dealt(amount: int) -> void:
	if amount <= 0:
		return

	gain_rage(int(amount * 0.5))

func on_damage_taken(amount: int) -> void:
	if amount <= 0:
		return

	gain_rage(int(amount * 1.5))

func tick_time(delta_seconds: float) -> void:
	super.tick_time(delta_seconds)

	if rage <= 0:
		rage_decay_accumulator = 0.0
		return

	rage_decay_accumulator += max(delta_seconds, 0.0)
	var rage_to_decay := int(floor(rage_decay_accumulator + CombatTime.TIME_EPSILON))
	if rage_to_decay <= 0:
		return

	rage_decay_accumulator -= float(rage_to_decay)
	rage = max(rage - rage_to_decay, 0)
	if rage <= 0:
		rage_decay_accumulator = 0.0
	rage_changed.emit(self)

func tick_one_second() -> void:
	tick_time(1.0)

func get_resource_snapshot(resource_id: String) -> Dictionary:
	if resource_id == "rage":
		return {
			"current": rage,
		}

	return super.get_resource_snapshot(resource_id)
