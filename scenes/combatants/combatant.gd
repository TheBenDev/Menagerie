## Base combatant node with stats, class-kit resources, statuses, action state, and damage handling.
class_name Combatant
extends Node

signal hp_changed(combatant: Combatant)
signal block_changed(combatant: Combatant)
signal statuses_changed(combatant: Combatant)
signal died(combatant: Combatant)
signal action_started(combatant: Combatant, action: CombatActionData)
signal action_resolved(combatant: Combatant, action: CombatActionData)
signal class_resource_changed(combatant: Combatant, resource_id: StringName)
signal stance_changed(combatant: Combatant, stance_id: StringName)

const ClassRunStateScript := preload("res://core/combat/classes/class_run_state.gd")
const ClassProfileDataScript := preload("res://core/combat/classes/class_profile_data.gd")
const ClassKitBuilderScript := preload("res://core/combat/classes/class_kit_builder.gd")
const CombatEffectLibraryScript := preload("res://core/combat/actions/combat_effect_library.gd")

@export var display_name: String = "Combatant"
@export var profile: CombatantProfile = null

var combatant_id: String = ""
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
var profile_configuration_valid: bool = false

var actions: Array[CombatActionData] = []

var class_profile: Resource = null
var class_run_state: Variant = null
var class_resources: Dictionary = {}
var class_resource_decay_accumulators: Dictionary = {}
var next_action_time_multiplier: float = 1.0

var is_busy: bool = false
var pending_action: CombatActionData = null
var action_finish_time: float = 0.0
var pending_targets: Array[Combatant] = []

func _ready() -> void:
	apply_profile()
	reset_runtime_state()

func apply_profile() -> void:
	profile_configuration_valid = false
	class_profile = null
	actions.clear()
	if profile == null:
		push_error("%s cannot apply a missing CombatantProfile." % name)
		return

	if not profile.display_name.is_empty():
		display_name = profile.display_name

	strength = profile.strength
	dexterity = profile.dexterity
	intelligence = profile.intelligence
	vitality = profile.vitality

	if profile.moveset != null:
		for action in profile.moveset.actions:
			if action != null:
				actions.append(action)

	var loaded_class_profile: Resource = profile.get("class_profile") as Resource
	if loaded_class_profile != null:
		if loaded_class_profile.get_script() != ClassProfileDataScript:
			push_error("%s profile has unsupported class_profile." % display_name)
			return
		class_profile = loaded_class_profile
		var validation_error: String = str(class_profile.call("validate"))
		if not validation_error.is_empty():
			push_error(validation_error)
			return

		actions.clear()
		for action in class_profile.call("all_actions"):
			var combat_action: CombatActionData = action as CombatActionData
			if combat_action != null and not actions.has(combat_action):
				actions.append(combat_action)
		_ensure_class_run_state()

	profile_configuration_valid = true

func reset_runtime_state() -> void:
	max_hp = max(vitality, 1) * 10
	hp = max_hp
	block = 0
	statuses.clear()
	outgoing_damage_multiplier = 1.0
	action_time_multiplier = 1.0
	class_resources.clear()
	class_resource_decay_accumulators.clear()
	next_action_time_multiplier = 1.0
	is_busy = false
	pending_action = null
	action_finish_time = 0.0
	pending_targets.clear()
	_initialize_class_resources()

func set_class_run_state(new_class_run_state: Variant) -> void:
	if class_profile == null:
		push_error("Combatant.set_class_run_state requires a combatant profile with ClassProfileData.")
		return
	if new_class_run_state == null or not (new_class_run_state is Object) or new_class_run_state.get_script() != ClassRunStateScript:
		push_error("Combatant.set_class_run_state requires a ClassRunState.")
		return
	class_run_state = new_class_run_state
	_ensure_class_run_state()

func apply_class_state_snapshot(snapshot: Dictionary) -> void:
	_ensure_class_run_state()
	if class_run_state == null:
		return
	class_run_state.apply_snapshot(snapshot)
	stance_changed.emit(self, class_run_state.active_stance_id)

func get_class_state_snapshot() -> Dictionary:
	_ensure_class_run_state()
	return class_run_state.to_snapshot() if class_run_state != null else {}

func get_class_resources_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for raw_resource_id in class_resources.keys():
		snapshot[String(raw_resource_id)] = int(class_resources[raw_resource_id])
	return snapshot

func apply_class_resources_snapshot(snapshot: Dictionary) -> void:
	for raw_resource_id in snapshot.keys():
		var resource_id := StringName(str(raw_resource_id))
		if resource_id != &"":
			set_class_resource_amount(resource_id, int(snapshot[raw_resource_id]))

func get_hotbar_slot_entries() -> Array[Dictionary]:
	_ensure_class_run_state()
	if class_profile == null or class_run_state == null:
		push_error("%s cannot build class hotbar slots without a valid class profile and run state." % display_name)
		return []
	return ClassKitBuilderScript.build_slots(self, class_profile, class_run_state)

func get_hotbar_slot_entry(slot_id: StringName) -> Dictionary:
	_ensure_class_run_state()
	if class_profile == null or class_run_state == null:
		push_error("%s cannot provide class hotbar slot %s without a valid class profile and run state." % [display_name, slot_id])
		return {}
	return ClassKitBuilderScript.slot_entry(slot_id, self, class_profile, class_run_state)

func resolve_hotbar_action(slot_id: StringName) -> PlayerActionData:
	_ensure_class_run_state()
	if class_profile == null or class_run_state == null:
		push_error("%s cannot resolve class hotbar slot %s without a valid class profile and run state." % [display_name, slot_id])
		return null
	return ClassKitBuilderScript.resolved_action_for_slot(slot_id, self, class_profile, class_run_state)

func on_hotbar_action_queued(slot_id: StringName) -> void:
	_ensure_class_run_state()
	if class_run_state == null or class_profile == null:
		return
	var flex_index: int = ClassKitBuilderScript.flex_slot_index(slot_id)
	if flex_index >= 0:
		class_run_state.replace_flex_slot(flex_index, class_profile)

func get_active_stance_id() -> StringName:
	_ensure_class_run_state()
	return class_run_state.active_stance_id if class_run_state != null else &""

func get_class_resource_amount(resource_id: StringName) -> int:
	if resource_id == &"":
		return 0
	if not _is_known_class_resource(resource_id):
		return 0
	return int(class_resources.get(resource_id, 0))

func set_class_resource_amount(resource_id: StringName, amount: int) -> void:
	if resource_id == &"":
		return
	if not _is_known_class_resource(resource_id):
		return
	var new_amount: int = max(amount, 0)
	if int(class_resources.get(resource_id, 0)) == new_amount:
		return
	class_resources[resource_id] = new_amount
	class_resource_changed.emit(self, resource_id)

func gain_class_resource(resource_id: StringName, amount: int) -> void:
	if resource_id == &"" or amount <= 0:
		return
	set_class_resource_amount(resource_id, get_class_resource_amount(resource_id) + amount)

func spend_class_resource(resource_id: StringName, amount: int) -> bool:
	if resource_id == &"":
		return false
	var cost: int = max(amount, 0)
	if cost <= 0:
		return true
	var current_amount := get_class_resource_amount(resource_id)
	if current_amount < cost:
		return false
	set_class_resource_amount(resource_id, current_amount - cost)
	return true

func class_resource_display_name(resource_id: StringName) -> String:
	if resource_id == &"":
		return ""
	if not _is_known_class_resource(resource_id):
		return ""
	var resource_data := _class_resource_data(resource_id)
	if resource_data != null:
		var value := str(resource_data.get("display_name")).strip_edges()
		if not value.is_empty():
			return value
	return String(resource_id).replace("_", " ").capitalize()

func class_resource_keyword_id(resource_id: StringName) -> StringName:
	if resource_id == &"":
		return &""
	if not _is_known_class_resource(resource_id):
		return &""
	var resource_data := _class_resource_data(resource_id)
	if resource_data != null and resource_data.has_method("resolved_keyword_id"):
		return resource_data.call("resolved_keyword_id")
	return StringName("resource.%s" % String(resource_id))

func class_resource_keyword_color(resource_id: StringName, fallback_color: Color) -> Color:
	if resource_id == &"":
		return fallback_color
	if not _is_known_class_resource(resource_id):
		return fallback_color
	var resource_data := _class_resource_data(resource_id)
	if resource_data != null:
		var value: Variant = resource_data.get("keyword_color")
		if value is Color:
			return value
	return fallback_color

func apply_class_stance_switch(stance_id: StringName) -> void:
	_ensure_class_run_state()
	if class_profile == null or class_run_state == null:
		push_error("Cannot switch class stance without class profile and run state.")
		return
	if not class_run_state.unlocked_stance_ids.has(stance_id):
		push_error("Cannot switch to locked class stance: %s." % stance_id)
		return
	var stance: Resource = class_profile.call("get_stance", stance_id) as Resource
	if stance == null:
		push_error("Cannot switch to unknown class stance: %s." % stance_id)
		return
	class_run_state.active_stance_id = stance_id
	var entry_effects: Variant = stance.get("entry_bonus_effect_data")
	if entry_effects is Array:
		var switch_action := class_profile.call("get_stance_switch_action", stance_id) as CombatActionData
		for raw_effect in entry_effects:
			if raw_effect is Dictionary:
				CombatEffectLibraryScript.apply_effect(raw_effect, self, [self], switch_action)
	class_run_state.reroll_flex_slots(class_profile)
	stance_changed.emit(self, stance_id)

func add_next_action_time_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		push_error("Class next action time multiplier must be positive.")
		return
	next_action_time_multiplier *= multiplier

func get_stat_value(stat_id: String) -> int:
	var field_name := str(StatId.PROFILE_FIELD_BY_ID.get(StatId.from_value(stat_id), ""))
	if field_name.is_empty():
		return 0

	return int(get(field_name))

func get_placeholder_color() -> Color:
	if profile == null:
		return Color(0.22, 0.24, 0.28)

	return profile.placeholder_color

func get_timeline_initial() -> String:
	if profile == null:
		return "?"

	return profile.timeline_initial

func get_timeline_color() -> Color:
	if profile == null:
		return Color.WHITE

	return profile.timeline_color

func get_battle_visual_scene() -> PackedScene:
	if profile == null:
		return null

	return profile.battle_visual_scene

func get_health_bar_config() -> Resource:
	if profile == null:
		return null

	return profile.health_bar

func get_resource_bar_configs() -> Array[Resource]:
	var configs: Array[Resource] = []
	if profile == null:
		return configs

	configs.append_array(profile.resource_bars)

	return configs

func get_hover_info() -> Resource:
	var info = null
	if profile != null and profile.has_method("get_hover_info"):
		info = profile.get_hover_info()
	if info == null:
		info = load("res://core/hover_info/hover_info_data.gd").new()

	info.title = display_name if not display_name.strip_edges().is_empty() else info.title
	if info.subtitle.strip_edges().is_empty():
		info.subtitle = "Combatant"
	info.panel_style = &"combatant"

	var authored_fields: Array = info.get("fields").duplicate()
	info.fields.clear()
	info.add_field("HP", "%s/%s" % [hp, max(max_hp, 1)])
	if block > 0:
		info.add_field("Block", str(block))
	info.add_field("STR", str(strength))
	info.add_field("DEX", str(dexterity))
	info.add_field("INT", str(intelligence))
	info.add_field("VIT", str(vitality))
	info.fields.append_array(authored_fields)
	return info

func get_resource_snapshot(resource_id: String) -> Dictionary:
	if resource_id == "health":
		return {
			"current": hp,
			"reference": max_hp,
			"bonus": block,
		}

	var class_resource_id := StringName(resource_id)
	if class_resource_id != &"" and not _is_known_class_resource(class_resource_id):
		return {}
	var resource_data := _class_resource_data(class_resource_id)
	if resource_data != null:
		return {
			"current": get_class_resource_amount(class_resource_id),
			"reference": max(int(resource_data.get("reference_value")), 1),
		}

	return {}

func start_action(action: CombatActionData, targets: Array[Combatant], current_time: float) -> void:
	if is_busy or action == null or hp <= 0:
		return

	is_busy = true
	pending_action = action
	pending_targets = targets.duplicate()
	var action_duration: float = CombatTime.snap_seconds(action.time_cost * action_time_multiplier_for_next_action())
	action_finish_time = CombatTime.snap_absolute_time(current_time + action_duration)

	action_started.emit(self, action)

func action_time_multiplier_for_next_action() -> float:
	var multiplier: float = action_time_multiplier * next_action_time_multiplier
	next_action_time_multiplier = 1.0
	return multiplier

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

	if block > 0 and incoming_damage > 0 and not packet.ignore_block:
		var blocked: int = min(block, incoming_damage)
		block -= blocked
		incoming_damage -= blocked
		block_changed.emit(self)

	var previous_hp := hp
	hp = max(hp - incoming_damage, 0)
	var actual_damage := previous_hp - hp
	hp_changed.emit(self)

	if packet.source != null:
		packet.source.on_damage_dealt(actual_damage)

	on_damage_taken(actual_damage)

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

func on_damage_dealt(amount: int) -> void:
	_apply_class_resource_damage_gain(amount, true)

func on_damage_taken(amount: int) -> void:
	_apply_class_resource_damage_gain(amount, false)

func tick_time(delta_seconds: float) -> void:
	_tick_statuses(delta_seconds)
	_tick_class_resources(delta_seconds)

func tick_one_second() -> void:
	tick_time(1.0)

func get_action_by_id(action_id: String) -> CombatActionData:
	for action in actions:
		if action != null and action.id == action_id:
			return action
	return null

func _ensure_class_run_state() -> void:
	if class_profile == null:
		return
	if class_run_state == null:
		class_run_state = ClassRunStateScript.new()
	class_run_state.configure_defaults(class_profile)

func _initialize_class_resources() -> void:
	if class_profile == null:
		return
	for class_resource in class_profile.call("class_resources"):
		var resource_data := class_resource as Resource
		if resource_data == null:
			continue
		var resource_id := StringName(str(resource_data.get("id")))
		if resource_id == &"":
			continue
		class_resources[resource_id] = max(int(resource_data.get("starting_amount")), 0)
		class_resource_decay_accumulators[resource_id] = 0.0

func _is_known_class_resource(resource_id: StringName) -> bool:
	if resource_id == &"":
		return false
	if class_profile == null:
		push_error("%s cannot use class resource %s without a class profile." % [display_name, resource_id])
		return false
	if _class_resource_data(resource_id) == null:
		push_error("%s references unknown class resource: %s." % [display_name, resource_id])
		return false
	return true

func _class_resource_data(resource_id: StringName) -> Resource:
	if class_profile == null or resource_id == &"":
		return null
	if not class_profile.has_method("get_class_resource"):
		return null
	return class_profile.call("get_class_resource", resource_id) as Resource

func _apply_class_resource_damage_gain(amount: int, is_damage_dealt: bool) -> void:
	if amount <= 0 or class_profile == null:
		return
	for class_resource in class_profile.call("class_resources"):
		var resource_data := class_resource as Resource
		if resource_data == null:
			continue
		var resource_id := StringName(str(resource_data.get("id")))
		if resource_id == &"":
			continue
		var gained := 0
		if is_damage_dealt and resource_data.has_method("damage_dealt_gain"):
			gained = int(resource_data.call("damage_dealt_gain", amount))
		elif not is_damage_dealt and resource_data.has_method("damage_taken_gain"):
			gained = int(resource_data.call("damage_taken_gain", amount))
		if gained > 0:
			gain_class_resource(resource_id, gained)

func _tick_class_resources(delta_seconds: float) -> void:
	if delta_seconds <= 0.0 or class_profile == null:
		return
	for class_resource in class_profile.call("class_resources"):
		var resource_data := class_resource as Resource
		if resource_data == null:
			continue
		var resource_id := StringName(str(resource_data.get("id")))
		var decay_per_second := float(resource_data.get("decay_per_second"))
		if resource_id == &"" or decay_per_second <= 0.0:
			continue
		var current_amount := get_class_resource_amount(resource_id)
		if current_amount <= 0:
			class_resource_decay_accumulators[resource_id] = 0.0
			continue
		var accumulator := float(class_resource_decay_accumulators.get(resource_id, 0.0))
		accumulator += delta_seconds * decay_per_second
		var decay_amount: int = int(floor(accumulator + CombatTime.TIME_EPSILON))
		if decay_amount <= 0:
			class_resource_decay_accumulators[resource_id] = accumulator
			continue
		accumulator -= float(decay_amount)
		class_resource_decay_accumulators[resource_id] = accumulator
		set_class_resource_amount(resource_id, max(current_amount - decay_amount, 0))
		if get_class_resource_amount(resource_id) <= 0:
			class_resource_decay_accumulators[resource_id] = 0.0

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
