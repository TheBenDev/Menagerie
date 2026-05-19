## Temporary combat-side container for one player or enemy side in a battle.
class_name CombatantGroup
extends RefCounted

var group_id: String = ""
var combatants: Array[Combatant] = []

func _init(new_group_id: String = "", initial_combatants: Array = []) -> void:
	group_id = new_group_id
	set_combatants(initial_combatants)

## Replaces this group's combatant list with valid unique combatants.
func set_combatants(new_combatants: Array) -> void:
	combatants.clear()
	for raw_combatant in new_combatants:
		var combatant := raw_combatant as Combatant
		add_combatant(combatant)

## Adds one combatant if it is valid and not already present.
func add_combatant(combatant: Combatant) -> bool:
	if combatant == null or combatants.has(combatant):
		return false

	combatants.append(combatant)
	return true

func remove_combatant(combatant: Combatant) -> bool:
	if combatant == null or not combatants.has(combatant):
		return false

	combatants.erase(combatant)
	return true

func clear() -> void:
	combatants.clear()

func is_empty() -> bool:
	return combatants.is_empty()

func size() -> int:
	return combatants.size()

func has_combatant(combatant: Combatant) -> bool:
	return combatant != null and combatants.has(combatant)

## Returns all combatants with HP remaining.
func get_living_combatants() -> Array[Combatant]:
	var living_combatants: Array[Combatant] = []
	for combatant in combatants:
		if combatant != null and combatant.hp > 0:
			living_combatants.append(combatant)

	return living_combatants

## Returns all combatants that have reached zero HP.
func get_dead_combatants() -> Array[Combatant]:
	var dead_combatants: Array[Combatant] = []
	for combatant in combatants:
		if combatant != null and combatant.hp <= 0:
			dead_combatants.append(combatant)

	return dead_combatants

func has_living_combatants() -> bool:
	return not get_living_combatants().is_empty()

func has_combatant_with_id(combatant_id: String) -> bool:
	var normalized_id := combatant_id.strip_edges()
	if normalized_id.is_empty():
		return false

	for combatant in combatants:
		if combatant == null:
			continue
		if _combatant_identity(combatant) == normalized_id:
			return true

	return false

func get_first_combatant() -> Combatant:
	for combatant in combatants:
		if combatant != null:
			return combatant

	return null

func get_first_living_combatant() -> Combatant:
	for combatant in combatants:
		if combatant != null and combatant.hp > 0:
			return combatant

	return null

static func _combatant_identity(combatant: Combatant) -> String:
	if combatant == null:
		return ""

	var explicit_id: Variant = combatant.get("combatant_id")
	if explicit_id != null and not str(explicit_id).strip_edges().is_empty():
		return str(explicit_id)
	if not str(combatant.name).is_empty():
		return str(combatant.name)

	return str(combatant.get_instance_id())
