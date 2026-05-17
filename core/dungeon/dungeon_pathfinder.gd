## Finds valid dungeon-map routes through descriptor connection graphs.
class_name DungeonPathfinder
extends RefCounted

const ValueReaderScript := preload("res://core/utils/value_reader.gd")

## Builds a symmetric node connection graph from dungeon node descriptors.
static func connection_graph_from_descriptors(descriptors: Array, use_linear_fallback: bool = true) -> Dictionary:
	var graph: Dictionary = {}
	var descriptor_ids: Array[int] = []
	var has_explicit_connections := false

	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			continue

		var descriptor: Dictionary = raw_descriptor
		var node_id: int = int(descriptor.get("id", -1))
		if node_id < 0:
			continue

		_add_unique_int(descriptor_ids, node_id)
		if not graph.has(node_id):
			graph[node_id] = []
		if descriptor.has("connections"):
			has_explicit_connections = true

	if has_explicit_connections:
		for raw_descriptor in descriptors:
			if not (raw_descriptor is Dictionary):
				continue

			var descriptor: Dictionary = raw_descriptor
			var node_id: int = int(descriptor.get("id", -1))
			if node_id < 0 or not graph.has(node_id):
				continue

			var raw_connections: Variant = descriptor.get("connections", [])
			if not (raw_connections is Array):
				continue

			for raw_connected_id in raw_connections:
				var connected_id: int = int(raw_connected_id)
				if graph.has(connected_id):
					_connect_node_ids(graph, node_id, connected_id)
	elif use_linear_fallback:
		descriptor_ids.sort()
		for index in range(descriptor_ids.size()):
			if index > 0:
				_connect_node_ids(graph, descriptor_ids[index], descriptor_ids[index - 1])
			if index < descriptor_ids.size() - 1:
				_connect_node_ids(graph, descriptor_ids[index], descriptor_ids[index + 1])

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
