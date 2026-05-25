## Shared rarity identifiers and helpers for run-scoped class rewards.
class_name ClassRarity
extends RefCounted

const COMMON := &"common"
const UNCOMMON := &"uncommon"
const RARE := &"rare"
const EPIC := &"epic"
const LEGENDARY := &"legendary"

const ALL: Array[StringName] = [
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
]

static func is_valid(rarity: StringName) -> bool:
	return ALL.has(rarity)

static func display_name(rarity: StringName) -> String:
	return String(rarity).replace("_", " ").capitalize()

