## Resource container listing the class-agnostic dungeon abilities available on the map hotbar.
class_name DungeonAbilityPool
extends Resource

@export var abilities: Array[Resource] = []

func get_hotbar_abilities(slot_count: int = 3) -> Array[Resource]:
	if slot_count <= 0:
		return [] as Array[Resource]

	var hotbar_abilities: Array[Resource] = []
	for ability in abilities:
		if ability == null:
			continue

		hotbar_abilities.append(ability)
		if hotbar_abilities.size() >= slot_count:
			break

	return hotbar_abilities
