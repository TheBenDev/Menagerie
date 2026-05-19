## Finds valid dungeon-map routes through descriptor connection graphs.
class_name DungeonPathfinder
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

## Builds a symmetric node connection graph from explicit dungeon descriptor connections.
static func connection_graph_from_descriptors(descriptors: Array) -> Dictionary:
	var graph: Dictionary = {}

	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			push_error("Dungeon connection graph requires dictionary descriptors.")
			return {}

		var descriptor: Dictionary = raw_descriptor
		var raw_id: Variant = descriptor.get("id", -1)
		var node_id: int = -1
		if typeof(raw_id) == TYPE_INT:
			node_id = int(raw_id)
		elif typeof(raw_id) == TYPE_FLOAT:
			if is_equal_approx(raw_id, floor(raw_id)):
				node_id = int(raw_id)
			else:
				push_error("Dungeon connection graph descriptor has non-integer id: %s" % raw_id)
				return {}
		elif typeof(raw_id) == TYPE_STRING:
			if raw_id.is_valid_int():
				node_id = int(raw_id)
			else:
				push_error("Dungeon connection graph descriptor has invalid string id: %s" % raw_id)
				return {}
		else:
			push_error("Dungeon connection graph descriptor has invalid id type: %s" % typeof(raw_id))
			return {}
		if node_id < 0:
			push_error("Dungeon connection graph descriptor is missing a valid id.")
			return {}
		if not descriptor.has("connections") or not (descriptor.get("connections") is Array):
			push_error("Dungeon node %s is missing explicit connections." % node_id)
			return {}

		if not graph.has(node_id):
			graph[node_id] = []

	for raw_descriptor in descriptors:
		var descriptor: Dictionary = raw_descriptor
		var raw_id: Variant = descriptor.get("id", -1)
		var node_id: int = -1
		if typeof(raw_id) == TYPE_INT:
			node_id = int(raw_id)
		elif typeof(raw_id) == TYPE_FLOAT and is_equal_approx(raw_id, floor(raw_id)):
			node_id = int(raw_id)
		elif typeof(raw_id) == TYPE_STRING and raw_id.is_valid_int():
			node_id = int(raw_id)
		for raw_connected_id in descriptor.get("connections", []):
			var connected_id: int = -1
			if typeof(raw_connected_id) == TYPE_INT:
				connected_id = int(raw_connected_id)
			elif typeof(raw_connected_id) == TYPE_FLOAT:
				if is_equal_approx(raw_connected_id, floor(raw_connected_id)):
					connected_id = int(raw_connected_id)
				else:
					push_error("Dungeon node %s has non-integer connection id: %s" % [node_id, raw_connected_id])
					return {}
			elif typeof(raw_connected_id) == TYPE_STRING:
				if raw_connected_id.is_valid_int():
					connected_id = int(raw_connected_id)
				else:
					push_error("Dungeon node %s has invalid string connection id: %s" % [node_id, raw_connected_id])
					return {}
			else:
				push_error("Dungeon node %s has invalid connection id type: %s" % [node_id, typeof(raw_connected_id)])
				return {}
			if not graph.has(connected_id):
				push_error("Dungeon node %s references missing connection %s." % [node_id, connected_id])
				return {}
			_connect_node_ids(graph, node_id, connected_id)

	return graph

## Returns an ordered path from start to destination, or an empty array when no allowed route exists.
static func find_path(
	start_node_id: int,
	destination_node_id: int,
	allowed_node_ids: Array,
	connection_graph: Dictionary
) -> Array[int]:
	var path: Array[int] = []
	var allowed_lookup: Dictionary = ValueReaderScript.int_lookup(allowed_node_ids)
	if not allowed_lookup.has(start_node_id) or not allowed_lookup.has(destination_node_id):
		return path
	if not connection_graph.has(start_node_id) or not connection_graph.has(destination_node_id):
		return path
	if start_node_id == destination_node_id:
		path.append(start_node_id)
		return path

	var queue: Array[int] = [start_node_id]
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	visited[start_node_id] = true

	while not queue.is_empty():
		var current_id: int = int(queue.pop_front())
		var neighbors: Array[int] = _sorted_ints(connection_graph.get(current_id, []))
		for neighbor_id in neighbors:
			if visited.has(neighbor_id) or not allowed_lookup.has(neighbor_id):
				continue

			visited[neighbor_id] = true
			came_from[neighbor_id] = current_id
			if neighbor_id == destination_node_id:
				return _reconstruct_path(start_node_id, destination_node_id, came_from)

			queue.append(neighbor_id)

	return path

static func _reconstruct_path(start_node_id: int, destination_node_id: int, came_from: Dictionary) -> Array[int]:
	var path: Array[int] = [destination_node_id]
	var current_id: int = destination_node_id
	while current_id != start_node_id:
		if not came_from.has(current_id):
			return []

		current_id = int(came_from[current_id])
		path.push_front(current_id)

	return path

static func _connect_node_ids(graph: Dictionary, first_id: int, second_id: int) -> void:
	if first_id == second_id:
		return
	if not graph.has(first_id) or not graph.has(second_id):
		return

	var first_neighbors: Array = graph[first_id]
	var second_neighbors: Array = graph[second_id]
	_add_unique_int(first_neighbors, second_id)
	_add_unique_int(second_neighbors, first_id)
	graph[first_id] = first_neighbors
	graph[second_id] = second_neighbors

static func _sorted_ints(values: Variant) -> Array[int]:
	var sorted_values: Array[int] = []
	if not (values is Array):
		return sorted_values

	for value in values:
		_add_unique_int(sorted_values, int(value))
	sorted_values.sort()
	return sorted_values

static func _add_unique_int(target: Array, value: int) -> bool:
	if value < 0 or target.has(value):
		return false

	target.append(value)
	return true
