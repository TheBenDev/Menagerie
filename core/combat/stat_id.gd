## Shared identifiers and resource-field mapping for combat stats.
class_name StatId
extends RefCounted

const STR := "STR"
const DEX := "DEX"
const INT := "INT"
const VIT := "VIT"

const ALL: Array[String] = [
	STR,
	DEX,
	INT,
	VIT,
]

const PROFILE_FIELD_BY_ID := {
	STR: "strength",
	DEX: "dexterity",
	INT: "intelligence",
	VIT: "vitality",
}

static func is_valid(stat_id: String) -> bool:
	return PROFILE_FIELD_BY_ID.has(stat_id)

static func from_value(value: Variant, default_id: String = STR) -> String:
	var normalized := str(value).strip_edges()
	if normalized.is_empty():
		return default_id

	var uppercase := normalized.to_upper()
	if PROFILE_FIELD_BY_ID.has(uppercase):
		return uppercase

	var field_name := normalized.to_lower()
	for stat_id in ALL:
		if str(PROFILE_FIELD_BY_ID.get(stat_id, "")) == field_name:
			return stat_id

	return default_id
