## Resolves namespaced combat effect IDs and applies their shared runtime behavior.
class_name CombatEffectLibrary
extends RefCounted

const EFFECT_DAMAGE := &"combat.damage"
const EFFECT_BLOCK := &"combat.block"
const EFFECT_APPLY_STATUS := &"status.apply"
const EFFECT_RAGE_GAIN := &"resource.rage.gain"
const EFFECT_STRENGTH_ADD := &"stat.strength.add"

const STATUS_ROOT_PATH := "res://data/statuses"
const STATUS_NAMESPACE_PREFIX := "status."


static func apply_effect(effect: Resource, source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> void:
	match _canonical_effect_id(_resource_string_name(effect, "effect_id")):
		EFFECT_DAMAGE:
			_apply_damage(effect, source, targets)
		EFFECT_BLOCK:
			_apply_block(effect, source)
		EFFECT_APPLY_STATUS:
			_apply_status(effect, targets)
		EFFECT_RAGE_GAIN:
			_apply_rage_gain(effect, source)
		EFFECT_STRENGTH_ADD:
			_apply_strength_add(effect, source, targets)
		_:
			if effect != null:
				push_warning("Unknown combat effect id: %s" % _resource_string_name(effect, "effect_id"))


static func estimate_power(effect: Resource, source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> float:
	match _canonical_effect_id(_resource_string_name(effect, "effect_id")):
		EFFECT_DAMAGE:
			return _estimate_damage_power(effect, source, targets)
		EFFECT_BLOCK:
			return float(max(_block_amount(effect), 0))
		EFFECT_STRENGTH_ADD:
			var amount: int = _effect_amount(effect, 0)
			if amount <= 0:
				return 0.0
			return float(amount * max(targets.size(), 1) * 4)
		_:
			return 0.0


static func status_path_for_id(status_id: StringName) -> String:
	var status_ref := String(status_id).strip_edges()
	if status_ref.is_empty():
		return ""
	if status_ref.begins_with("res://"):
		return status_ref
	if status_ref.begins_with(STATUS_NAMESPACE_PREFIX):
		status_ref = status_ref.substr(STATUS_NAMESPACE_PREFIX.length())

	var segments: PackedStringArray = status_ref.split(".", false)
	if segments.is_empty():
		return ""

	return STATUS_ROOT_PATH.path_join("/".join(segments)) + ".tres"


static func _apply_damage(effect: Resource, source: Combatant, targets: Array[Combatant]) -> void:
	var damage_amount: int = _calculate_damage(effect, source)
	if damage_amount <= 0:
		return

	for target in targets:
		if target == null or target.hp <= 0:
			continue

		var packet := DamagePacket.new(source, target, damage_amount)
		if source != null:
			source.modify_outgoing_damage(packet)
		target.modify_incoming_damage(packet)

		packet.amount = max(packet.amount, 0)
		target.take_damage(packet)


static func _apply_block(effect: Resource, source: Combatant) -> void:
	if source == null or not source.has_method("add_block"):
		return

	source.add_block(_block_amount(effect))


static func _apply_status(effect: Resource, targets: Array[Combatant]) -> void:
	var status_data: Resource = _status_data_for_effect(effect)
	if status_data == null:
		return

	var duration_override_seconds: float = _resource_float(effect, "duration_override_seconds", -1.0)
	for target in targets:
		if target == null or target.hp <= 0 or not target.has_method("add_status"):
			continue
		target.add_status(status_data, duration_override_seconds)


static func _apply_rage_gain(effect: Resource, source: Combatant) -> void:
	if source == null or not source.has_method("gain_rage"):
		return

	source.gain_rage(_effect_amount(effect, 0))


static func _apply_strength_add(effect: Resource, source: Combatant, targets: Array[Combatant]) -> void:
	var amount: int = _effect_amount(effect, 0)
	if amount == 0:
		return

	var affected_targets: Array[Combatant] = targets.duplicate()
	if affected_targets.is_empty() and source != null:
		affected_targets.append(source)

	for target in affected_targets:
		if target == null or target.hp <= 0:
			continue

		target.strength = max(target.strength + amount, 0)


static func _estimate_damage_power(effect: Resource, source: Combatant, targets: Array[Combatant]) -> float:
	var total_damage := 0.0
	if targets.is_empty():
		return float(_calculate_damage(effect, source))

	for target in targets:
		total_damage += float(_estimate_damage(effect, source, target))

	return total_damage


static func _calculate_damage(effect: Resource, source: Combatant) -> int:
	var stat_value := 0
	if source != null:
		stat_value = source.get_stat_value(_resource_string(effect, "scaling_stat", "STR"))

	var base_damage: int = _resource_int(effect, "base_damage", _resource_int(effect, "base_amount", 0))
	var scaling_multiplier: float = _resource_float(effect, "scaling_multiplier", 0.0)
	var scaled_damage: float = floor(float(stat_value) * scaling_multiplier)
	return max(base_damage + int(scaled_damage), 0)


static func _estimate_damage(effect: Resource, source: Combatant, target: Combatant) -> int:
	if target != null and target.hp <= 0:
		return 0

	var damage_amount: int = _calculate_damage(effect, source)
	if damage_amount <= 0:
		return 0

	var packet := DamagePacket.new(source, target, damage_amount)
	if source != null:
		source.modify_outgoing_damage(packet)
	if target != null:
		target.modify_incoming_damage(packet)

	var blocked_damage := 0
	if target != null and target.block > 0:
		blocked_damage = min(target.block, max(packet.amount, 0))

	return max(packet.amount - blocked_damage, 0)


static func _block_amount(effect: Resource) -> int:
	var amount: int = _effect_amount(effect, 0)
	if amount != 0:
		return amount

	return _resource_int(effect, "base_block", 0)


static func _effect_amount(effect: Resource, default_value: int) -> int:
	return _resource_int(effect, "amount", _resource_int(effect, "base_amount", default_value))


static func _status_data_for_effect(effect: Resource) -> Resource:
	var status_id: StringName = _resource_string_name(effect, "status_id")
	if not String(status_id).is_empty():
		var status_path := status_path_for_id(status_id)
		if status_path.is_empty():
			return null

		var status_data: Resource = load(status_path) as Resource
		if status_data == null:
			push_warning("Status id %s could not be loaded from %s." % [status_id, status_path])
		return status_data

	if effect != null:
		return effect.get("status_data") as Resource

	return null


static func _canonical_effect_id(effect_id: StringName) -> StringName:
	match String(effect_id):
		"damage":
			return EFFECT_DAMAGE
		"block":
			return EFFECT_BLOCK
		"apply_status", "status":
			return EFFECT_APPLY_STATUS
		"rage", "rage_gain":
			return EFFECT_RAGE_GAIN
		"strength", "strength_add":
			return EFFECT_STRENGTH_ADD
		_:
			return effect_id


static func _resource_string_name(resource: Resource, field_name: String, default_value: StringName = &"") -> StringName:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return default_value


static func _resource_string(resource: Resource, field_name: String, default_value: String) -> String:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is StringName or value is String:
		return str(value)

	return default_value


static func _resource_int(resource: Resource, field_name: String, default_value: int) -> int:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is int or value is float:
		return int(value)

	return default_value


static func _resource_float(resource: Resource, field_name: String, default_value: float) -> float:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value
