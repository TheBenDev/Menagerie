## Action effect that deals stat-scaled damage packets to each valid target.
class_name DamageEffect
extends "res://core/combat/data/effects/action_effect.gd"

func _init() -> void:
	effect_id = CombatEffectLibrary.EFFECT_DAMAGE

func apply(source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> void:
	var damage_amount: int = _calculate_damage(source)
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

func estimate_power(source: Combatant, targets: Array[Combatant], _action: CombatActionData) -> float:
	var total_damage := 0.0
	if targets.is_empty():
		return float(_calculate_damage(source))

	for target in targets:
		total_damage += float(_estimate_damage(source, target))

	return total_damage

func _calculate_damage(source: Combatant) -> int:
	var stat_value: int = 0
	if source != null:
		stat_value = source.get_stat_value(scaling_stat)

	var scaled_damage: float = floor(float(stat_value) * scaling_multiplier)
	return max(base_damage + int(scaled_damage), 0)

func _estimate_damage(source: Combatant, target: Combatant) -> int:
	if target != null and target.hp <= 0:
		return 0

	var damage_amount := _calculate_damage(source)
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
