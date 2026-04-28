class_name Combatant
extends Node

const CombatTime := preload("res://scripts/combat/time/combat_time.gd")

signal hp_changed(combatant: Combatant)
signal block_changed(combatant: Combatant)
signal statuses_changed(combatant: Combatant)
signal died(combatant: Combatant)
signal action_started(combatant: Combatant, action: CombatActionData)
signal action_resolved(combatant: Combatant, action: CombatActionData)

@export var display_name: String = "Combatant"
@export var is_enemy: bool = false
@export var profile: Resource = null

var strength: int = 5
var dexterity: int = 5
var intelligence: int = 5
var vitality: int = 5
var max_hp: int = 0
var hp: int = 0
var block: int = 0
var statuses: Dictionary = {}
var outgoing_damage_multiplier: float = 1.0
var action_time_multiplier: float = 1.0

var actions: Array[CombatActionData] = []

var is_busy: bool = false
var pending_action: CombatActionData = null
var action_finish_time: float = 0.0
var pending_targets: Array[Combatant] = []

func _ready() -> void:
	apply_profile()
	reset_runtime_state()

func apply_profile() -> void:
	if profile == null:
		return

	var profile_display_name: Variant = profile.get("display_name")
	if profile_display_name is String and not profile_display_name.is_empty():
		display_name = profile_display_name

	strength = _profile_int("strength", strength)
	dexterity = _profile_int("dexterity", dexterity)
	intelligence = _profile_int("intelligence", intelligence)
	vitality = _profile_int("vitality", vitality)

	actions.clear()
	var profile_moveset := profile.get("moveset") as Resource
	if profile_moveset != null:
		var moveset_actions: Variant = profile_moveset.get("actions")
		if moveset_actions is Array:
			for action in moveset_actions:
				if action is CombatActionData:
					actions.append(action)

func reset_runtime_state() -> void:
	max_hp = max(vitality, 1) * 10
	hp = max_hp
	block = 0
	statuses.clear()
	outgoing_damage_multiplier = 1.0
	action_time_multiplier = 1.0
	is_busy = false
	pending_action = null
	action_finish_time = 0.0
	pending_targets.clear()

func get_stat_value(stat_id: String) -> int:
	match stat_id:
		"STR":
			return strength
		"DEX":
			return dexterity
		"INT":
			return intelligence
		"VIT":
			return vitality
		_:
			return 0

func get_placeholder_color() -> Color:
	if profile == null:
		return Color(0.22, 0.24, 0.28)

	return profile.get("placeholder_color") as Color

func get_timeline_initial() -> String:
	if profile == null:
		return "?"

	return str(profile.get("timeline_initial"))

func get_timeline_color() -> Color:
	if profile == null:
		return Color.WHITE

	return profile.get("timeline_color") as Color

func get_health_bar_config() -> Resource:
	if profile == null:
		return null

	return profile.get("health_bar") as Resource

func get_resource_bar_configs() -> Array[Resource]:
	var configs: Array[Resource] = []
	if profile == null:
		return configs

	var raw_configs: Variant = profile.get("resource_bars")
	if raw_configs is Array:
		for config in raw_configs:
			if config is Resource:
				configs.append(config)

	return configs

func get_resource_snapshot(resource_id: String) -> Dictionary:
	if resource_id == "health":
		return {
			"current": hp,
			"reference": max_hp,
			"bonus": block,
		}

	return {}

func start_action(action: CombatActionData, targets: Array[Combatant], current_time: float) -> void:
	if is_busy or action == null or hp <= 0:
		return

	is_busy = true
	pending_action = action
	pending_targets = targets.duplicate()
	var action_duration: float = CombatTime.snap_seconds(action.time_cost * action_time_multiplier)
	action_finish_time = CombatTime.snap_absolute_time(current_time + action_duration)

	action_started.emit(self, action)

func resolve_pending_action() -> void:
	if pending_action == null:
		return

	var action: CombatActionData = pending_action

	ActionResolver.resolve_action(self, pending_targets, action)

	is_busy = false
	pending_action = null
	pending_targets.clear()

	action_resolved.emit(self, action)

func cancel_pending_action() -> void:
	if pending_action == null:
		return

	is_busy = false
	pending_action = null
	action_finish_time = 0.0
	pending_targets.clear()

func take_damage(packet: DamagePacket) -> void:
	if packet == null or hp <= 0:
		return

	var incoming_damage: int = max(packet.amount, 0)

	if block > 0 and incoming_damage > 0:
		var blocked: int = min(block, incoming_damage)
		block -= blocked
		incoming_damage -= blocked
		block_changed.emit(self)

	hp = max(hp - incoming_damage, 0)
	hp_changed.emit(self)

	if packet.source != null and packet.source.has_method("on_damage_dealt"):
		packet.source.on_damage_dealt(incoming_damage)

	on_damage_taken(incoming_damage)

	if hp <= 0:
		died.emit(self)

func add_block(amount: int) -> void:
	if amount <= 0:
		return

	block += amount
	block_changed.emit(self)

func add_status(status_data: Resource, duration_override_seconds: float = -1.0) -> void:
	if status_data == null:
		return

	var status_id := str(status_data.get("id"))
	if status_id.is_empty():
		return

	var duration := duration_override_seconds
	if duration < 0.0:
		duration = float(status_data.get("duration_seconds"))
	if duration <= 0.0:
		return

	var current_remaining := get_status_remaining(status_id)
	statuses[status_id] = {
		"data": status_data,
		"remaining_seconds": max(duration, current_remaining),
	}
	statuses_changed.emit(self)

func has_status(status_id: String) -> bool:
	return statuses.has(status_id) and get_status_remaining(status_id) > 0.0

func get_status_remaining(status_id: String) -> float:
	if not statuses.has(status_id):
		return 0.0

	var state: Dictionary = statuses[status_id]
	return float(state.get("remaining_seconds", 0.0))

func modify_outgoing_damage(packet: DamagePacket) -> void:
	if packet != null and packet.amount > 0 and not is_equal_approx(outgoing_damage_multiplier, 1.0):
		packet.amount = max(int(round(float(packet.amount) * outgoing_damage_multiplier)), 0)
	_apply_damage_multiplier(packet, "outgoing_damage_multiplier")

func modify_incoming_damage(packet: DamagePacket) -> void:
	_apply_damage_multiplier(packet, "incoming_damage_multiplier")

func on_damage_dealt(_amount: int) -> void:
	pass

func on_damage_taken(_amount: int) -> void:
	pass

func tick_time(delta_seconds: float) -> void:
	_tick_statuses(delta_seconds)

func tick_one_second() -> void:
	tick_time(1.0)

func _tick_statuses(delta_seconds: float) -> void:
	if statuses.is_empty():
		return

	var expired_statuses: Array[String] = []
	var did_update_statuses := false
	for status_id in statuses.keys():
		var state: Dictionary = statuses[status_id]
		var remaining := float(state.get("remaining_seconds", 0.0)) - delta_seconds
		did_update_statuses = true
		if remaining <= 0.0:
			expired_statuses.append(status_id)
		else:
			state["remaining_seconds"] = remaining
			statuses[status_id] = state

	for status_id in expired_statuses:
		statuses.erase(status_id)

	if did_update_statuses:
		statuses_changed.emit(self)

func _apply_damage_multiplier(packet: DamagePacket, multiplier_field: String) -> void:
	if packet == null or packet.amount <= 0:
		return

	var multiplier := 1.0
	for state in statuses.values():
		if not state is Dictionary:
			continue
		var status_data: Variant = state.get("data", null)
		if status_data == null:
			continue
		var status_multiplier: Variant = status_data.get(multiplier_field)
		if status_multiplier is int or status_multiplier is float:
			multiplier *= float(status_multiplier)

	if not is_equal_approx(multiplier, 1.0):
		packet.amount = max(int(round(float(packet.amount) * multiplier)), 0)

func _profile_int(field_name: String, default_value: int) -> int:
	var value: Variant = profile.get(field_name)
	if value is int:
		return value

	return default_value
