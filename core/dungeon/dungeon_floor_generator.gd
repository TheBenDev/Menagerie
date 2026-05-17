## Deterministic factory that builds dungeon floor node descriptors from a seed, floor layer, and difficulty.
class_name DungeonFloorGenerator
extends RefCounted

const DungeonNodeDataScript := preload("res://core/dungeon/dungeon_node_data.gd")
const DungeonFloorGenerationConfigScript := preload("res://core/dungeon/dungeon_floor_generation_config.gd")
const DEFAULT_DUNGEON_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_encounter_pool.tres")
const DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL := preload("res://core/dungeon/encounters/default_dungeon_combat_encounter_pool.tres")

const EMPTY_SIZE := Vector2i.ONE
const LARGE_SIZE := Vector2i(3, 3)
const DEFAULT_COMBAT_ENCOUNTER_ID := "training_ghoul_fight"
const DEFAULT_COMBAT_ENCOUNTER_PROFILE_PATH := "res://core/dungeon/encounters/combat/training_ghoul_fight.tres"
const DEFAULT_ENEMY_PROFILE_PATH := "res://scenes/combatants/enemies/training_ghoul/training_ghoul_profile.tres"
const ENEMY_INSTANCE_PROFILE_PATH := "combatant_profile_path"
const ENEMY_INSTANCE_POSITION_ID := "position_id"
const ENEMY_INSTANCE_LEVEL := "enemy_level"
const ENEMY_INSTANCE_STAT_SEED := "stat_seed"
const ENEMY_INSTANCE_ID := "instance_id"
const TYPE_SORT_ORDER := {
	DungeonNodeDataScript.TYPE_EMPTY: 0,
	DungeonNodeDataScript.TYPE_FIGHT: 1,
	DungeonNodeDataScript.TYPE_ENCOUNTER: 2,
	DungeonNodeDataScript.TYPE_HAVEN: 3,
	DungeonNodeDataScript.TYPE_BOSS: 4,
}
const FALLBACK_NODE_DESCRIPTORS := [
	{"id": 0, "type": "Haven", "grid": Vector2i(0, 0), "size": Vector2i(3, 3), "connections": [1]},
	{"id": 1, "type": "Empty", "grid": Vector2i(3, 1), "size": Vector2i(1, 1), "connections": [0, 2]},
	{"id": 2, "type": "Empty", "grid": Vector2i(4, 1), "size": Vector2i(1, 1), "connections": [1, 3]},
	{"id": 3, "type": "Fight", "grid": Vector2i(5, 0), "size": Vector2i(3, 3), "combat_encounter_id": DEFAULT_COMBAT_ENCOUNTER_ID, "combat_encounter_profile_path": DEFAULT_COMBAT_ENCOUNTER_PROFILE_PATH, "enemy": DEFAULT_ENEMY_PROFILE_PATH, "connections": [2, 4]},
	{"id": 4, "type": "Empty", "grid": Vector2i(8, 1), "size": Vector2i(1, 1), "connections": [3, 5]},
	{"id": 5, "type": "Empty", "grid": Vector2i(9, 1), "size": Vector2i(1, 1), "connections": [4, 6]},
	{"id": 6, "type": "Encounter", "grid": Vector2i(10, 0), "size": Vector2i(3, 3), "encounter_id": "mysterious_shrine", "connections": [5, 7]},
	{"id": 7, "type": "Empty", "grid": Vector2i(13, 1), "size": Vector2i(1, 1), "connections": [6, 8]},
	{"id": 8, "type": "Empty", "grid": Vector2i(14, 1), "size": Vector2i(1, 1), "connections": [7, 9]},
	{"id": 9, "type": "Fight", "grid": Vector2i(15, 0), "size": Vector2i(3, 3), "combat_encounter_id": DEFAULT_COMBAT_ENCOUNTER_ID, "combat_encounter_profile_path": DEFAULT_COMBAT_ENCOUNTER_PROFILE_PATH, "enemy": DEFAULT_ENEMY_PROFILE_PATH, "connections": [8, 10]},
	{"id": 10, "type": "Empty", "grid": Vector2i(18, 1), "size": Vector2i(1, 1), "connections": [9, 11]},
	{"id": 11, "type": "Empty", "grid": Vector2i(19, 1), "size": Vector2i(1, 1), "connections": [10, 12]},
	{"id": 12, "type": "Boss", "grid": Vector2i(20, 0), "size": Vector2i(3, 3), "is_boss": true, "combat_encounter_id": DEFAULT_COMBAT_ENCOUNTER_ID, "combat_encounter_profile_path": DEFAULT_COMBAT_ENCOUNTER_PROFILE_PATH, "enemy": DEFAULT_ENEMY_PROFILE_PATH, "connections": [11]},
]

static func generate_floor(
	base_seed: String,
	floor_layer: int,
	difficulty_id: String,
	config: Resource = null,
	encounter_pool: Resource = null,
	combat_encounter_pool: Resource = null
) -> Array:
	seed(base_seed.hash())
	return generate_floor_from_global_rng(floor_layer, difficulty_id, config, encounter_pool, combat_encounter_pool)

static func generate_floor_from_global_rng(
	floor_layer: int,
	difficulty_id: String,
	config: Resource = null,
	encounter_pool: Resource = null,
	combat_encounter_pool: Resource = null
) -> Array:
	var active_config: Resource = config
	if active_config == null:
		active_config = DungeonFloorGenerationConfigScript.new()
	var active_encounter_pool: Resource = encounter_pool
	if active_encounter_pool == null:
		active_encounter_pool = DEFAULT_DUNGEON_ENCOUNTER_POOL
	var active_combat_encounter_pool: Resource = combat_encounter_pool
	if active_combat_encounter_pool == null:
		active_combat_encounter_pool = DEFAULT_DUNGEON_COMBAT_ENCOUNTER_POOL

	var resolved_layer: int = max(floor_layer, 1)
	var resolved_difficulty := difficulty_id.strip_edges().to_lower()
	if resolved_difficulty.is_empty():
		resolved_difficulty = "normal"

	var settings := _build_settings(resolved_layer, resolved_difficulty, active_config, active_encounter_pool, active_combat_encounter_pool)
	for retry_index in range(max(settings.max_generation_retries, 1)):
		var descriptors := _try_generate_floor(settings)
		if not descriptors.is_empty() and validate_descriptors(descriptors, settings.grid_size):
			return descriptors

	return _fallback_descriptors()

static func validate_descriptors(descriptors: Array, grid_size: Vector2i = Vector2i.ZERO) -> bool:
	if descriptors.is_empty():
		return false

	var ids := {}
	var nodes_by_id := {}
	var haven_id := -1
	var boss_id := -1
	var occupied_large_cells := {}
	var connector_cells := {}
	var max_grid := grid_size

	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			return false

		var descriptor: Dictionary = raw_descriptor
		var node_id := int(descriptor.get("id", -1))
		var node_type := str(descriptor.get("type", ""))
		var grid_position: Vector2i = descriptor.get("grid", Vector2i.ZERO)
		var grid_node_size: Vector2i = descriptor.get("size", EMPTY_SIZE if node_type == DungeonNodeDataScript.TYPE_EMPTY else LARGE_SIZE)
		if node_id < 0 or ids.has(node_id):
			return false
		if grid_position.x < 0 or grid_position.y < 0 or grid_node_size.x <= 0 or grid_node_size.y <= 0:
			return false
		if max_grid != Vector2i.ZERO and (grid_position.x + grid_node_size.x > max_grid.x or grid_position.y + grid_node_size.y > max_grid.y):
			return false

		ids[node_id] = true
		nodes_by_id[node_id] = descriptor
		if node_type == DungeonNodeDataScript.TYPE_HAVEN:
			haven_id = node_id
		elif node_type == DungeonNodeDataScript.TYPE_BOSS or bool(descriptor.get("is_boss", false)):
			boss_id = node_id

		if node_type == DungeonNodeDataScript.TYPE_EMPTY:
			if connector_cells.has(grid_position):
				return false
			connector_cells[grid_position] = node_id
		else:
			for x in range(grid_position.x, grid_position.x + grid_node_size.x):
				for y in range(grid_position.y, grid_position.y + grid_node_size.y):
					var cell := Vector2i(x, y)
					if occupied_large_cells.has(cell):
						return false
					occupied_large_cells[cell] = node_id

	if haven_id < 0 or boss_id < 0:
		return false

	for connector_cell in connector_cells.keys():
		if occupied_large_cells.has(connector_cell):
			return false

	var graph := {}
	for raw_id in nodes_by_id.keys():
		var node_id: int = raw_id
		graph[node_id] = []

	for raw_descriptor in descriptors:
		var descriptor: Dictionary = raw_descriptor
		var node_id := int(descriptor.get("id", -1))
		for raw_connection in descriptor.get("connections", []):
			var connected_id := int(raw_connection)
			if node_id == connected_id or not nodes_by_id.has(connected_id):
				return false
			if not _connection_cells_touch(descriptor, nodes_by_id[connected_id]):
				return false
			if not graph[node_id].has(connected_id):
				graph[node_id].append(connected_id)

	for node_id in graph.keys():
		for connected_id in graph[node_id]:
			if not graph.has(connected_id) or not graph[connected_id].has(node_id):
				return false

	var reachable := _reachable_ids(graph, haven_id)
	return reachable.has(boss_id) and reachable.size() == nodes_by_id.size()

static func _try_generate_floor(settings: Dictionary) -> Array:
	var grid_size: Vector2i = settings.grid_size
	var major_nodes: Array = []
	var large_occupied := {}

	var haven_position := Vector2i(0, randi_range(0, max(grid_size.y - LARGE_SIZE.y, 0)))
	var haven := _make_major("haven", DungeonNodeDataScript.TYPE_HAVEN, haven_position, false)
	major_nodes.append(haven)
	_reserve_large_node(haven, large_occupied)

	var boss_position := Vector2i(grid_size.x - LARGE_SIZE.x, randi_range(0, max(grid_size.y - LARGE_SIZE.y, 0)))
	var boss := _make_major("boss", DungeonNodeDataScript.TYPE_BOSS, boss_position, true)
	if not _can_place_major(boss_position, LARGE_SIZE, grid_size, large_occupied, int(settings.room_padding)):
		return []
	major_nodes.append(boss)
	_reserve_large_node(boss, large_occupied)

	var fights := _place_fights(settings, grid_size, large_occupied)
	if fights.size() < int(settings.fight_count):
		return []
	_assign_combat_encounters(fights, settings)
	for fight in fights:
		major_nodes.append(fight)
	_assign_combat_encounters([boss], settings)

	var encounters := _place_major_nodes(
		settings,
		grid_size,
		large_occupied,
		DungeonNodeDataScript.TYPE_ENCOUNTER,
		"encounter",
		int(settings.encounter_count)
	)
	if encounters.size() < int(settings.encounter_count):
		return []
	if not _assign_encounter_ids(encounters, settings):
		return []
	for encounter in encounters:
		major_nodes.append(encounter)

	var connector_nodes := {}
	var edges := {}
	for node in major_nodes:
		edges[node.uid] = []

	var route_nodes := []
	var branch_nodes := []
	var progress_nodes := []
	progress_nodes.append_array(fights)
	progress_nodes.append_array(encounters)
	_sort_major_nodes_by_position(progress_nodes)
	for progress_node in progress_nodes:
		if progress_nodes.size() > 1 and randf() < float(settings.branch_chance):
			branch_nodes.append(progress_node)
		else:
			route_nodes.append(progress_node)
	if route_nodes.is_empty():
		var promoted = branch_nodes.pop_front()
		route_nodes.append(promoted)

	var main_route := [haven]
	main_route.append_array(route_nodes)
	main_route.append(boss)
	_sort_middle_route(main_route)

	var blocked_cells := _large_node_cells(major_nodes)
	for index in range(main_route.size() - 1):
		if not _connect_nodes_with_path(main_route[index], main_route[index + 1], grid_size, blocked_cells, connector_nodes, edges, float(settings.path_noise)):
			return []

	for branch_node in branch_nodes:
		var nearest_main: Variant = _nearest_major(branch_node, main_route)
		if nearest_main == null:
			return []
		if not _connect_nodes_with_path(nearest_main, branch_node, grid_size, blocked_cells, connector_nodes, edges, float(settings.path_noise)):
			return []
		if randf() < float(settings.extra_connection_chance):
			var second_main: Variant = _nearest_major(branch_node, main_route, nearest_main.uid)
			if second_main != null:
				_connect_nodes_with_path(second_main, branch_node, grid_size, blocked_cells, connector_nodes, edges, float(settings.path_noise))

	for index in range(main_route.size() - 2):
		if randf() < float(settings.extra_connection_chance):
			_connect_nodes_with_path(main_route[index], main_route[index + 2], grid_size, blocked_cells, connector_nodes, edges, float(settings.path_noise))

	var all_nodes := []
	all_nodes.append_array(major_nodes)
	for connector in connector_nodes.values():
		all_nodes.append(connector)

	return _export_descriptors(all_nodes, edges)

static func _build_settings(
	floor_layer: int,
	difficulty_id: String,
	config: Resource,
	encounter_pool: Resource,
	combat_encounter_pool: Resource
) -> Dictionary:
	var difficulty_index := _difficulty_index(difficulty_id)
	var layer_offset: int = max(floor_layer - 1, 0)
	var width: int = min(
		config.base_grid_width + layer_offset * config.grid_width_per_layer + difficulty_index * config.grid_width_per_difficulty,
		config.max_grid_width
	)
	var height: int = min(
		config.base_grid_height + layer_offset * config.grid_height_per_layer + difficulty_index * config.grid_height_per_difficulty,
		config.max_grid_height
	)
	var fight_count: int = clamp(
		config.base_fight_count + layer_offset * config.fight_count_per_layer + difficulty_index * config.fight_count_per_difficulty,
		config.min_fight_count,
		config.max_fight_count
	)
	var encounter_count: int = clamp(
		config.base_encounter_count + layer_offset * config.encounter_count_per_layer + difficulty_index * config.encounter_count_per_difficulty,
		config.min_encounter_count,
		config.max_encounter_count
	)
	var typed_encounter_pool := encounter_pool as Resource
	var available_encounters: Array = []
	if typed_encounter_pool != null:
		available_encounters = typed_encounter_pool.call("available_for_floor", floor_layer)
	if typed_encounter_pool == null or available_encounters.is_empty():
		encounter_count = 0
	var typed_combat_encounter_pool := combat_encounter_pool as Resource
	return {
		"floor_layer": floor_layer,
		"grid_size": Vector2i(max(width, 9), max(height, 3)),
		"fight_count": fight_count,
		"encounter_count": encounter_count,
		"encounter_pool": typed_encounter_pool,
		"combat_encounter_pool": typed_combat_encounter_pool,
		"enemy_level_range": _enemy_level_range_for_floor(config, floor_layer),
		"branch_chance": clampf(config.base_branch_chance + layer_offset * config.branch_chance_per_layer + difficulty_index * config.branch_chance_per_difficulty, 0.0, 1.0),
		"extra_connection_chance": clampf(config.base_extra_connection_chance + layer_offset * config.extra_connection_chance_per_layer + difficulty_index * config.extra_connection_chance_per_difficulty, 0.0, 1.0),
		"path_noise": clampf(config.base_path_noise + layer_offset * config.path_noise_per_layer + difficulty_index * config.path_noise_per_difficulty, 0.0, 1.0),
		"room_padding": max(config.room_padding, 0),
		"max_room_placement_attempts": max(config.max_room_placement_attempts, 1),
		"max_generation_retries": max(config.max_generation_retries, 1),
	}

static func _place_fights(settings: Dictionary, grid_size: Vector2i, large_occupied: Dictionary) -> Array:
	return _place_major_nodes(
		settings,
		grid_size,
		large_occupied,
		DungeonNodeDataScript.TYPE_FIGHT,
		"fight",
		int(settings.fight_count)
	)

static func _place_major_nodes(
	settings: Dictionary,
	grid_size: Vector2i,
	large_occupied: Dictionary,
	node_type: String,
	uid_prefix: String,
	node_count: int
) -> Array:
	var placed_nodes := []
	var candidates := []
	for x in range(LARGE_SIZE.x + 1, grid_size.x - LARGE_SIZE.x - LARGE_SIZE.x):
		for y in range(0, grid_size.y - LARGE_SIZE.y + 1):
			candidates.append(Vector2i(x, y))
	_shuffle(candidates)

	var attempts := 0
	var candidate_index := 0
	while placed_nodes.size() < node_count and attempts < int(settings.max_room_placement_attempts) and candidate_index < candidates.size():
		attempts += 1
		var position: Vector2i = candidates[candidate_index]
		candidate_index += 1
		if not _can_place_major(position, LARGE_SIZE, grid_size, large_occupied, int(settings.room_padding)):
			continue
		var placed_node := _make_major("%s_%s" % [uid_prefix, placed_nodes.size()], node_type, position, false)
		placed_nodes.append(placed_node)
		_reserve_large_node(placed_node, large_occupied)

	return placed_nodes

static func _assign_encounter_ids(encounter_nodes: Array, settings: Dictionary) -> bool:
	var encounter_pool := settings.get("encounter_pool", null) as Resource
	if encounter_nodes.is_empty():
		return true
	if encounter_pool == null:
		return false

	for encounter_node in encounter_nodes:
		var encounter_data := encounter_pool.call("pick_for_floor", int(settings.floor_layer)) as Resource
		if encounter_data == null or String(encounter_data.get("id")).is_empty():
			return false
		encounter_node["encounter_id"] = String(encounter_data.get("id"))

	return true

static func _assign_combat_encounters(combat_nodes: Array, settings: Dictionary) -> void:
	for combat_node in combat_nodes:
		if not (combat_node is Dictionary):
			continue

		var encounter_data := _pick_combat_encounter(settings)
		if encounter_data == null:
			_assign_default_combat_encounter(combat_node)
			continue

		var encounter_id := String(encounter_data.get("id")).strip_edges()
		var encounter_profile_path := _combat_encounter_profile_path(encounter_data, settings)
		var enemy_profile_path := _primary_enemy_profile_path(encounter_data)
		if encounter_id.is_empty() or encounter_profile_path.is_empty() or enemy_profile_path.is_empty():
			_assign_default_combat_encounter(combat_node)
			continue

		combat_node["combat_encounter_id"] = encounter_id
		combat_node["combat_encounter_profile_path"] = encounter_profile_path
		combat_node["enemy"] = enemy_profile_path
		combat_node["enemy_instances"] = _build_enemy_instances(encounter_data, settings, bool(combat_node.get("is_boss", false)))

static func _pick_combat_encounter(settings: Dictionary) -> Resource:
	var combat_encounter_pool := settings.get("combat_encounter_pool", null) as Resource
	if combat_encounter_pool == null:
		return null
	if not combat_encounter_pool.has_method("pick_for_floor"):
		return null

	return combat_encounter_pool.call("pick_for_floor", int(settings.floor_layer)) as Resource

static func _combat_encounter_profile_path(encounter_data: Resource, settings: Dictionary) -> String:
	if encounter_data == null:
		return ""

	var combat_encounter_pool := settings.get("combat_encounter_pool", null) as Resource
	if combat_encounter_pool != null and combat_encounter_pool.has_method("profile_path_for_id"):
		var pool_path := str(combat_encounter_pool.call("profile_path_for_id", StringName(str(encounter_data.get("id"))))).strip_edges()
		if not pool_path.is_empty():
			return pool_path

	return str(encounter_data.resource_path).strip_edges()

static func _primary_enemy_profile_path(encounter_data: Resource) -> String:
	if encounter_data == null:
		return ""
	if encounter_data.has_method("primary_enemy_profile_path"):
		return str(encounter_data.call("primary_enemy_profile_path")).strip_edges()

	var enemy_slots: Array = encounter_data.get("enemy_slots")
	for slot in enemy_slots:
		if not (slot is Dictionary):
			continue
		var slot_data: Dictionary = slot
		var profile_path := str(slot_data.get("combatant_profile_path", "")).strip_edges()
		if not profile_path.is_empty():
			return profile_path

	return ""

static func _build_enemy_instances(encounter_data: Resource, settings: Dictionary, is_boss: bool) -> Array[Dictionary]:
	var enemy_instances: Array[Dictionary] = []
	var enemy_slots := _enemy_slots(encounter_data)
	if enemy_slots.is_empty():
		return enemy_instances

	var min_count := _encounter_count_value(encounter_data, "min_enemy_count", 1)
	var max_count := _encounter_count_value(encounter_data, "max_enemy_count", min_count)
	min_count = clamp(min_count, 1, enemy_slots.size())
	max_count = clamp(max(max_count, min_count), min_count, enemy_slots.size())
	var enemy_count := randi_range(min_count, max_count)
	var enemy_level_range: Vector2i = settings.get("enemy_level_range", Vector2i(0, 5))
	for index in range(enemy_count):
		var slot_data: Dictionary = enemy_slots[index]
		var profile_path := str(slot_data.get(DungeonCombatEncounterData.SLOT_COMBATANT_PROFILE_PATH, "")).strip_edges()
		if profile_path.is_empty():
			continue

		var enemy_level := enemy_level_range.y if is_boss else randi_range(enemy_level_range.x, enemy_level_range.y)
		enemy_instances.append({
			ENEMY_INSTANCE_ID: "enemy_%s" % (index + 1),
			ENEMY_INSTANCE_PROFILE_PATH: profile_path,
			ENEMY_INSTANCE_POSITION_ID: str(slot_data.get(DungeonCombatEncounterData.SLOT_POSITION_ID, "EnemySlot%s" % (index + 1))),
			ENEMY_INSTANCE_LEVEL: enemy_level,
			ENEMY_INSTANCE_STAT_SEED: int(randi()),
		})

	return enemy_instances

static func _enemy_slots(encounter_data: Resource) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if encounter_data == null:
		return slots

	var enemy_slots_value: Variant = encounter_data.get("enemy_slots")
	if not (enemy_slots_value is Array):
		return slots

	for slot in enemy_slots_value:
		if slot is Dictionary:
			slots.append(slot)

	return slots

static func _encounter_count_value(encounter_data: Resource, field_name: String, default_value: int) -> int:
	if encounter_data == null:
		return default_value

	var value: Variant = encounter_data.get(field_name)
	if value is int or value is float:
		return int(value)

	return default_value

static func _assign_default_combat_encounter(combat_node: Dictionary) -> void:
	combat_node["combat_encounter_id"] = DEFAULT_COMBAT_ENCOUNTER_ID
	combat_node["combat_encounter_profile_path"] = DEFAULT_COMBAT_ENCOUNTER_PROFILE_PATH
	combat_node["enemy"] = DEFAULT_ENEMY_PROFILE_PATH

static func _connect_nodes_with_path(
	from_node: Dictionary,
	to_node: Dictionary,
	grid_size: Vector2i,
	blocked_cells: Dictionary,
	connector_nodes: Dictionary,
	edges: Dictionary,
	path_noise: float
) -> bool:
	var start := _edge_connector_cell(from_node, to_node, grid_size, blocked_cells)
	var target := _edge_connector_cell(to_node, from_node, grid_size, blocked_cells)
	if start == Vector2i(-1, -1) or target == Vector2i(-1, -1):
		return false

	var path := _find_path(start, target, grid_size, blocked_cells, path_noise)
	if path.is_empty():
		return false

	var previous_uid: String = from_node.uid
	for cell in path:
		var connector_uid := _connector_uid(cell)
		if not connector_nodes.has(connector_uid):
			connector_nodes[connector_uid] = {
				"uid": connector_uid,
				"type": DungeonNodeDataScript.TYPE_EMPTY,
				"grid": cell,
				"size": EMPTY_SIZE,
				"is_boss": false,
			}
			edges[connector_uid] = []
		_add_edge(edges, previous_uid, connector_uid)
		previous_uid = connector_uid

	_add_edge(edges, previous_uid, to_node.uid)
	return true

static func _find_path(start: Vector2i, target: Vector2i, grid_size: Vector2i, blocked_cells: Dictionary, path_noise: float) -> Array:
	if start == target:
		return [start]

	var open := [start]
	var came_from := {}
	var g_score := {start: 0.0}
	var f_score := {start: float(_manhattan(start, target))}
	var closed := {}
	while not open.is_empty():
		var current := _pop_lowest_score(open, f_score)
		if current == target:
			return _reconstruct_path(came_from, current)
		closed[current] = true

		var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
		_shuffle(directions)
		for direction in directions:
			var neighbor: Vector2i = current + direction
			if not _is_in_bounds(neighbor, grid_size) or (blocked_cells.has(neighbor) and neighbor != target) or closed.has(neighbor):
				continue
			var random_cost := randf() * path_noise
			var directness_cost := float(_manhattan(neighbor, target)) * 0.10
			var tentative_g := float(g_score[current]) + 1.0 + random_cost + directness_cost
			if not g_score.has(neighbor) or tentative_g < float(g_score[neighbor]):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + float(_manhattan(neighbor, target))
				if not open.has(neighbor):
					open.append(neighbor)

	return []

static func _edge_connector_cell(from_node: Dictionary, to_node: Dictionary, grid_size: Vector2i, blocked_cells: Dictionary) -> Vector2i:
	var candidates := _edge_connector_candidates(from_node, to_node)
	for candidate in candidates:
		if _is_in_bounds(candidate, grid_size) and not blocked_cells.has(candidate):
			return candidate
	return Vector2i(-1, -1)

static func _edge_connector_candidates(from_node: Dictionary, to_node: Dictionary) -> Array:
	var from_center := _node_center(from_node)
	var to_center := _node_center(to_node)
	var candidates := []
	if abs(to_center.x - from_center.x) >= abs(to_center.y - from_center.y):
		if to_center.x >= from_center.x:
			candidates.append(Vector2i(from_node.grid.x + from_node.size.x, from_center.y))
		else:
			candidates.append(Vector2i(from_node.grid.x - 1, from_center.y))
		if to_center.y >= from_center.y:
			candidates.append(Vector2i(from_center.x, from_node.grid.y + from_node.size.y))
		else:
			candidates.append(Vector2i(from_center.x, from_node.grid.y - 1))
	else:
		if to_center.y >= from_center.y:
			candidates.append(Vector2i(from_center.x, from_node.grid.y + from_node.size.y))
		else:
			candidates.append(Vector2i(from_center.x, from_node.grid.y - 1))
		if to_center.x >= from_center.x:
			candidates.append(Vector2i(from_node.grid.x + from_node.size.x, from_center.y))
		else:
			candidates.append(Vector2i(from_node.grid.x - 1, from_center.y))

	for x in range(from_node.grid.x, from_node.grid.x + from_node.size.x):
		candidates.append(Vector2i(x, from_node.grid.y - 1))
		candidates.append(Vector2i(x, from_node.grid.y + from_node.size.y))
	for y in range(from_node.grid.y, from_node.grid.y + from_node.size.y):
		candidates.append(Vector2i(from_node.grid.x - 1, y))
		candidates.append(Vector2i(from_node.grid.x + from_node.size.x, y))
	candidates.sort_custom(_sort_positions_by_target.bind(to_center))
	return _unique_positions(candidates)

static func _export_descriptors(nodes: Array, edges: Dictionary) -> Array:
	var haven := {}
	var boss := {}
	var middle := []
	for node in nodes:
		match str(node.type):
			DungeonNodeDataScript.TYPE_HAVEN:
				haven = node
			DungeonNodeDataScript.TYPE_BOSS:
				boss = node
			_:
				middle.append(node)

	if haven.is_empty() or boss.is_empty():
		return []

	middle.sort_custom(_sort_export_nodes)
	var export_nodes := [haven]
	export_nodes.append_array(middle)
	export_nodes.append(boss)

	var id_by_uid := {}
	for index in export_nodes.size():
		id_by_uid[export_nodes[index].uid] = index

	var descriptors := []
	for index in export_nodes.size():
		var node: Dictionary = export_nodes[index]
		var descriptor := {
			"id": index,
			"type": str(node.type),
			"grid": node.grid,
			"size": node.size,
		}
		if bool(node.get("is_boss", false)):
			descriptor["is_boss"] = true
		if str(node.type) == DungeonNodeDataScript.TYPE_ENCOUNTER:
			descriptor["encounter_id"] = str(node.get("encounter_id", ""))
		if _is_combat_node_type(str(node.type)):
			descriptor["combat_encounter_id"] = str(node.get("combat_encounter_id", DEFAULT_COMBAT_ENCOUNTER_ID))
			descriptor["combat_encounter_profile_path"] = str(node.get("combat_encounter_profile_path", DEFAULT_COMBAT_ENCOUNTER_PROFILE_PATH))
			descriptor["enemy"] = str(node.get("enemy", DEFAULT_ENEMY_PROFILE_PATH))
			descriptor["enemy_instances"] = _duplicate_enemy_instances(node.get("enemy_instances", []))

		var connections: Array[int] = []
		for connected_uid in edges.get(node.uid, []):
			if id_by_uid.has(connected_uid):
				connections.append(int(id_by_uid[connected_uid]))
		connections.sort()
		descriptor["connections"] = connections
		descriptors.append(descriptor)

	return descriptors

static func _is_combat_node_type(node_type: String) -> bool:
	return node_type == DungeonNodeDataScript.TYPE_FIGHT or node_type == DungeonNodeDataScript.TYPE_BOSS

static func _connection_cells_touch(first: Dictionary, second: Dictionary) -> bool:
	var first_type := str(first.get("type", ""))
	var second_type := str(second.get("type", ""))
	if first_type == DungeonNodeDataScript.TYPE_EMPTY and second_type == DungeonNodeDataScript.TYPE_EMPTY:
		return _manhattan(first.get("grid", Vector2i.ZERO), second.get("grid", Vector2i.ZERO)) == 1
	if first_type == DungeonNodeDataScript.TYPE_EMPTY:
		return _cell_touches_node(first.get("grid", Vector2i.ZERO), second)
	if second_type == DungeonNodeDataScript.TYPE_EMPTY:
		return _cell_touches_node(second.get("grid", Vector2i.ZERO), first)
	return false

static func _cell_touches_node(cell: Vector2i, node: Dictionary) -> bool:
	var grid_position: Vector2i = node.get("grid", Vector2i.ZERO)
	var grid_node_size: Vector2i = node.get("size", LARGE_SIZE)
	if cell.x >= grid_position.x and cell.x < grid_position.x + grid_node_size.x:
		return cell.y == grid_position.y - 1 or cell.y == grid_position.y + grid_node_size.y
	if cell.y >= grid_position.y and cell.y < grid_position.y + grid_node_size.y:
		return cell.x == grid_position.x - 1 or cell.x == grid_position.x + grid_node_size.x
	return false

static func _fallback_descriptors() -> Array:
	var descriptors := []
	for descriptor in FALLBACK_NODE_DESCRIPTORS:
		descriptors.append(descriptor.duplicate(true))
	return descriptors

static func _make_major(uid: String, node_type: String, grid_position: Vector2i, is_boss: bool) -> Dictionary:
	return {
		"uid": uid,
		"type": node_type,
		"grid": grid_position,
		"size": LARGE_SIZE,
		"is_boss": is_boss,
	}

static func _reserve_large_node(node: Dictionary, occupied_cells: Dictionary) -> void:
	for cell in _cells_for_rect(node.grid, node.size):
		occupied_cells[cell] = node.uid

static func _can_place_major(position: Vector2i, node_size: Vector2i, grid_size: Vector2i, occupied_cells: Dictionary, padding: int) -> bool:
	if position.x < 0 or position.y < 0 or position.x + node_size.x > grid_size.x or position.y + node_size.y > grid_size.y:
		return false
	for x in range(position.x - padding, position.x + node_size.x + padding):
		for y in range(position.y - padding, position.y + node_size.y + padding):
			if occupied_cells.has(Vector2i(x, y)):
				return false
	return true

static func _large_node_cells(nodes: Array) -> Dictionary:
	var blocked := {}
	for node in nodes:
		if str(node.type) == DungeonNodeDataScript.TYPE_EMPTY:
			continue
		for cell in _cells_for_rect(node.grid, node.size):
			blocked[cell] = true
	return blocked

static func _cells_for_rect(position: Vector2i, node_size: Vector2i) -> Array:
	var cells := []
	for x in range(position.x, position.x + node_size.x):
		for y in range(position.y, position.y + node_size.y):
			cells.append(Vector2i(x, y))
	return cells

static func _node_center(node: Dictionary) -> Vector2i:
	var grid_position: Vector2i = node.grid
	var grid_node_size: Vector2i = node.size
	return Vector2i(
		grid_position.x + floori(float(grid_node_size.x) / 2.0),
		grid_position.y + floori(float(grid_node_size.y) / 2.0)
	)

static func _nearest_major(source: Dictionary, candidates: Array, excluded_uid: String = "") -> Variant:
	var nearest: Variant = null
	var nearest_distance := 999999
	for candidate in candidates:
		if str(candidate.uid) == excluded_uid:
			continue
		var distance := _manhattan(_node_center(source), _node_center(candidate))
		if nearest == null or distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

static func _sort_middle_route(route: Array) -> void:
	if route.size() <= 2:
		return
	var start = route[0]
	var end = route[route.size() - 1]
	var middle := route.slice(1, route.size() - 1)
	_sort_major_nodes_by_position(middle)
	route.clear()
	route.append(start)
	route.append_array(middle)
	route.append(end)

static func _sort_major_nodes_by_position(nodes: Array) -> void:
	nodes.sort_custom(_sort_export_nodes)

static func _sort_export_nodes(first: Dictionary, second: Dictionary) -> bool:
	var first_grid: Vector2i = first.grid
	var second_grid: Vector2i = second.grid
	if first_grid.x != second_grid.x:
		return first_grid.x < second_grid.x
	if first_grid.y != second_grid.y:
		return first_grid.y < second_grid.y
	return int(TYPE_SORT_ORDER.get(str(first.type), 99)) < int(TYPE_SORT_ORDER.get(str(second.type), 99))

static func _sort_positions_by_target(first: Vector2i, second: Vector2i, target: Vector2i) -> bool:
	var first_distance := _manhattan(first, target)
	var second_distance := _manhattan(second, target)
	if first_distance != second_distance:
		return first_distance < second_distance
	if first.x != second.x:
		return first.x < second.x
	return first.y < second.y

static func _unique_positions(positions: Array) -> Array:
	var unique := []
	var seen := {}
	for position in positions:
		if seen.has(position):
			continue
		seen[position] = true
		unique.append(position)
	return unique

static func _add_edge(edges: Dictionary, first_uid: String, second_uid: String) -> void:
	if first_uid == second_uid:
		return
	if not edges.has(first_uid):
		edges[first_uid] = []
	if not edges.has(second_uid):
		edges[second_uid] = []
	if not edges[first_uid].has(second_uid):
		edges[first_uid].append(second_uid)
	if not edges[second_uid].has(first_uid):
		edges[second_uid].append(first_uid)

static func _connector_uid(cell: Vector2i) -> String:
	return "empty_%s_%s" % [cell.x, cell.y]

static func _pop_lowest_score(open: Array, f_score: Dictionary) -> Vector2i:
	var best_index := 0
	for index in range(1, open.size()):
		var position: Vector2i = open[index]
		var best_position: Vector2i = open[best_index]
		var score := float(f_score.get(position, 999999.0))
		var best_score := float(f_score.get(best_position, 999999.0))
		if score < best_score or (is_equal_approx(score, best_score) and (position.x < best_position.x or (position.x == best_position.x and position.y < best_position.y))):
			best_index = index
	return open.pop_at(best_index)

static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path := [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

static func _reachable_ids(graph: Dictionary, start_id: int) -> Dictionary:
	var reachable := {}
	var queue := [start_id]
	while not queue.is_empty():
		var node_id: int = queue.pop_front()
		if reachable.has(node_id):
			continue
		reachable[node_id] = true
		for connected_id in graph.get(node_id, []):
			if not reachable.has(connected_id):
				queue.append(connected_id)
	return reachable

static func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := randi_range(0, index)
		var value = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value

static func _difficulty_index(difficulty_id: String) -> int:
	match difficulty_id:
		"easy":
			return 0
		"hard":
			return 2
		_:
			return 1

static func _enemy_level_range_for_floor(config: Resource, floor_layer: int) -> Vector2i:
	if config != null and config.has_method("enemy_level_range_for_floor"):
		return config.call("enemy_level_range_for_floor", floor_layer)

	return Vector2i(0, 5)

static func _duplicate_enemy_instances(raw_enemy_instances: Variant) -> Array[Dictionary]:
	var enemy_instances: Array[Dictionary] = []
	if not (raw_enemy_instances is Array):
		return enemy_instances

	for raw_enemy_instance in raw_enemy_instances:
		if raw_enemy_instance is Dictionary:
			enemy_instances.append(raw_enemy_instance.duplicate(true))

	return enemy_instances

static func _is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

static func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return abs(first.x - second.x) + abs(first.y - second.y)
