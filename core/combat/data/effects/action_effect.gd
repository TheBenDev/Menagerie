## Namespaced combat action effect data resolved by CombatEffectLibrary.
class_name ActionEffect
extends Resource

@export var effect_id: StringName = &""
@export var amount: int = 0
@export var base_damage: int = 0
@export_enum("STR", "DEX", "INT", "VIT") var scaling_stat: String = "STR"
@export var scaling_multiplier: float = 0.0
@export var status_id: StringName = &""
@export var duration_override_seconds: float = -1.0

func apply(_source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> void:
	if String(effect_id).is_empty():
		return

	CombatEffectLibrary.apply_effect(self, _source, _targets, _action)

func estimate_power(_source: Combatant, _targets: Array[Combatant], _action: CombatActionData) -> float:
	if String(effect_id).is_empty():
		return 0.0

	return CombatEffectLibrary.estimate_power(self, _source, _targets, _action)
