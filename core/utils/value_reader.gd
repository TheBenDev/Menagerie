## Shared value conversion helpers for Resource, Dictionary, and Variant-based runtime data.
class_name ValueReader
extends RefCounted

static func variant_int(source: Variant, field_name: String, default_value: int) -> int:
	if source is Dictionary:
		return int(source.get(field_name, default_value))

	if source != null:
		var value: Variant = source.get(field_name)
		if value is int or value is float:
			return int(value)

	return default_value

static func resource_int(resource: Resource, field_name: String, default_value: int) -> int:
	return variant_int(resource, field_name, default_value)

static func resource_float(resource: Resource, field_name: String, default_value: float) -> float:
	if resource == null:
		return default_value

	var value: Variant = resource.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value

static func string_name_from_variant(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return &""

static func string_name_array(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value in values:
			var id := string_name_from_variant(value)
			if id != &"":
				result.append(id)
	elif values is PackedStringArray:
		for value in values:
			var id := StringName(str(value))
			if id != &"":
				result.append(id)
	elif values is StringName:
		if values != &"":
			result.append(values)
	elif values is String:
		var id := StringName(values)
		if id != &"":
			result.append(id)
	return result

static func string_array(values: Variant) -> Array[String]:
	var strings: Array[String] = []
	for value in string_name_array(values):
		strings.append(String(value))
	return strings

static func int_lookup(values: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for value in values:
		lookup[int(value)] = true

	return lookup
