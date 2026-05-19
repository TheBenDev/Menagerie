## Validates and normalizes network-bound dictionaries into plain serializable payloads.
class_name NetworkSnapshotService
extends RefCounted

static func plain_copy(value: Variant, path: String = "payload") -> Variant:
	var value_type := typeof(value)
	match value_type:
		TYPE_NIL:
			return null
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var copied_array: Array = []
			for index in range((value as Array).size()):
				copied_array.append(plain_copy((value as Array)[index], "%s[%s]" % [path, index]))
			return copied_array
		TYPE_DICTIONARY:
			var copied_dictionary: Dictionary = {}
			var source: Dictionary = value
			for raw_key in source.keys():
				if typeof(raw_key) != TYPE_STRING and typeof(raw_key) != TYPE_STRING_NAME and typeof(raw_key) != TYPE_INT:
					push_error("Unsupported network dictionary key at %s: %s." % [path, raw_key])
					return null
				var key := str(raw_key)
				copied_dictionary[key] = plain_copy(source[raw_key], "%s.%s" % [path, key])
			return copied_dictionary
		_:
			push_error("Unsupported network payload value at %s. Type: %s." % [path, value_type])
			return null

static func is_plain_payload(value: Variant, path: String = "payload") -> bool:
	var value_type := typeof(value)
	match value_type:
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for index in range((value as Array).size()):
				if not is_plain_payload((value as Array)[index], "%s[%s]" % [path, index]):
					return false
			return true
		TYPE_DICTIONARY:
			var source: Dictionary = value
			for raw_key in source.keys():
				if typeof(raw_key) != TYPE_STRING and typeof(raw_key) != TYPE_STRING_NAME and typeof(raw_key) != TYPE_INT:
					push_error("Unsupported network dictionary key at %s: %s." % [path, raw_key])
					return false
				if not is_plain_payload(source[raw_key], "%s.%s" % [path, raw_key]):
					return false
			return true
		_:
			push_error("Unsupported network payload value at %s. Type: %s." % [path, value_type])
			return false
