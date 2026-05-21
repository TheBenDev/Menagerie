## Resolves namespaced combat effect data dictionaries and applies their shared runtime behavior.
class_name CombatEffectLibrary
extends RefCounted

const EFFECT_DAMAGE := &"combat.damage"
const EFFECT_BLOCK := &"combat.block"
const EFFECT_APPLY_STATUS := &"status.apply"
const EFFECT_RAGE_GAIN := &"resource.rage.gain"
const EFFECT_STRENGTH_ADD := &"stat.strength.add"


const STATUS_ROOT_PATH := "res://core/statuses"
const STATUS_NAMESPACE_PREFIX := "status."


static func apply_effect(effect_data: Dictionary, source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> void:
	var effect_id := _canonical_effect_id(_effect_id(effect_data))
	if String(effect_id).is_empty():
		return

	match effect_id:
		EFFECT_DAMAGE:
			_apply_damage(effect_data, source, targets)
		EFFECT_BLOCK:
			_apply_block(effect_data, source)
		EFFECT_APPLY_STATUS:
			_apply_status(effect_data, targets)
		EFFECT_RAGE_GAIN:
			_apply_rage_gain(effect_data, source)
		EFFECT_STRENGTH_ADD:
			_apply_strength_add(effect_data, source, targets)
		_:
			push_warning("Unknown combat effect id: %s" % _effect_id(effect_data))


static func estimate_power(effect_data: Dictionary, source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> float:
	match _canonical_effect_id(_effect_id(effect_data)):
		EFFECT_DAMAGE:
			return _estimate_damage_power(effect_data, source, targets)
		EFFECT_BLOCK:
			return float(max(_block_amount(effect_data), 0))
		EFFECT_STRENGTH_ADD:
			var amount: int = _effect_amount(effect_data, 0)
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

static func effect_id_for_data(effect_data: Dictionary) -> StringName:
	return _canonical_effect_id(_effect_id(effect_data))

static func damage_breakdown(effect_data: Dictionary, source: Combatant) -> Dictionary:
	var stat_id := StatId.from_value(_data_string(effect_data, "scaling_stat", StatId.STR))
	var stat_value := 0
	if source != null:
		stat_value = source.get_stat_value(stat_id)

	var base_damage: int = _data_int(effect_data, "base_damage", _data_int(effect_data, "base_amount", 0))
	var scaling_multiplier: float = _data_float(effect_data, "scaling_multiplier", 0.0)
	var scaled_damage: int = int(floor(float(stat_value) * scaling_multiplier))
	return {
		"base_damage": base_damage,
		"scaling_stat": stat_id,
		"stat_value": stat_value,
		"scaling_multiplier": scaling_multiplier,
		"scaled_damage": scaled_damage,
		"total_damage": max(base_damage + scaled_damage, 0),
	}

static func status_data_for_effect(effect_data: Dictionary) -> Resource:
	return _status_data_for_effect(effect_data)


static func _apply_damage(effect_data: Dictionary, source: Combatant, targets: Array[Combatant]) -> void:
	var damage_amount: int = _calculate_damage(effect_data, source)
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


static func _apply_block(effect_data: Dictionary, source: Combatant) -> void:
	if source == null or not source.has_method("add_block"):
		return

	source.add_block(_block_amount(effect_data))


static func _apply_status(effect_data: Dictionary, targets: Array[Combatant]) -> void:
	var status_data: Resource = _status_data_for_effect(effect_data)
	if status_data == null:
		return

	var duration_override_seconds: float = _data_float(effect_data, "duration_override_seconds", -1.0)
	for target in targets:
		if target == null or target.hp <= 0 or not target.has_method("add_status"):
			continue
		target.add_status(status_data, duration_override_seconds)


static func _apply_rage_gain(effect_data: Dictionary, source: Combatant) -> void:
	if source == null or not source.has_method("gain_rage"):
		return

	source.gain_rage(_effect_amount(effect_data, 0))


static func _apply_strength_add(effect_data: Dictionary, source: Combatant, targets: Array[Combatant]) -> void:
	var amount: int = _effect_amount(effect_data, 0)
	if amount == 0:
		return

	var affected_targets: Array[Combatant] = targets.duplicate()
	if affected_targets.is_empty() and source != null:
		affected_targets.append(source)

	for target in affected_targets:
		if target == null or target.hp <= 0:
			continue

		target.strength = max(target.strength + amount, 0)


static func _estimate_damage_power(effect_data: Dictionary, source: Combatant, targets: Array[Combatant]) -> float:
	var total_damage := 0.0
	if targets.is_empty():
		return float(_calculate_damage(effect_data, source))

	for target in targets:
		total_damage += float(_estimate_damage(effect_data, source, target))

	return total_damage


static func _calculate_damage(effect_data: Dictionary, source: Combatant) -> int:
	return int(damage_breakdown(effect_data, source).get("total_damage", 0))


static func _estimate_damage(effect_data: Dictionary, source: Combatant, target: Combatant) -> int:
	if target != null and target.hp <= 0:
		return 0

	var damage_amount: int = _calculate_damage(effect_data, source)
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


static func _block_amount(effect_data: Dictionary) -> int:
	var amount: int = _effect_amount(effect_data, 0)
	if amount != 0:
		return amount

	return _data_int(effect_data, "base_block", 0)


static func _effect_amount(effect_data: Dictionary, default_value: int) -> int:
	return _data_int(effect_data, "amount", _data_int(effect_data, "base_amount", default_value))


static func _status_data_for_effect(effect_data: Dictionary) -> Resource:
	var status_id: StringName = _data_string_name(effect_data, "status_id")
	if not String(status_id).is_empty():
		var status_path := status_path_for_id(status_id)
		if status_path.is_empty():
			return null

		var status_data: Resource = load(status_path) as Resource
		if status_data == null:
			push_warning("Status id %s could not be loaded from %s." % [status_id, status_path])
		return status_data

	return effect_data.get("status_data", null) as Resource


static func _effect_id(effect_data: Dictionary) -> StringName:
	return _data_string_name(effect_data, "id")


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


static func _data_string_name(effect_data: Dictionary, field_name: String, default_value: StringName = &"") -> StringName:
	var value: Variant = effect_data.get(field_name, default_value)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return default_value


static func _data_string(effect_data: Dictionary, field_name: String, default_value: String) -> String:
	var value: Variant = effect_data.get(field_name, default_value)
	if value is StringName or value is String:
		return str(value)

	return default_value


static func _data_int(effect_data: Dictionary, field_name: String, default_value: int) -> int:
	var value: Variant = effect_data.get(field_name, default_value)
	if value is int or value is float:
		return int(value)

	return default_value


static func _data_float(effect_data: Dictionary, field_name: String, default_value: float) -> float:
	var value: Variant = effect_data.get(field_name, default_value)
	if value is int or value is float:
		return float(value)

	return default_value
