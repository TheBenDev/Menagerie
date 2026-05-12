## Controls generated dungeon map progression, node reveal state, completed combat results, and node event routing.
extends Node

signal node_event_emitted(event: Dictionary)
signal node_completed(node_id: int, node_type: String)

const DungeonNodeDataScript := preload("res://core/dungeon/dungeon_node_data.gd")
const DungeonNodeEventHelperScript := preload("res://core/dungeon/dungeon_node_event_helper.gd")
const DungeonNodeViewScript := preload("res://scenes/dungeon/dungeon_node_view.gd")

const GRID_CELL_SIZE := 72.0
const START_NODE_ID := 0
const DEFAULT_NODE_DESCRIPTORS := [
	{"id": 0, "type": "Haven", "grid": Vector2i(0, 0), "size": Vector2i(3, 3)},
	{"id": 1, "type": "Empty", "grid": Vector2i(3, 1), "size": Vector2i(1, 1)},
	{"id": 2, "type": "Empty", "grid": Vector2i(4, 1), "size": Vector2i(1, 1)},
	{"id": 3, "type": "Fight", "grid": Vector2i(5, 0), "size": Vector2i(3, 3)},
	{"id": 4, "type": "Empty", "grid": Vector2i(8, 1), "size": Vector2i(1, 1)},
	{"id": 5, "type": "Empty", "grid": Vector2i(9, 1), "size": Vector2i(1, 1)},
	{"id": 6, "type": "Fight", "grid": Vector2i(10, 0), "size": Vector2i(3, 3)},
	{"id": 7, "type": "Empty", "grid": Vector2i(13, 1), "size": Vector2i(1, 1)},
	{"id": 8, "type": "Empty", "grid": Vector2i(14, 1), "size": Vector2i(1, 1)},
	{"id": 9, "type": "Fight", "grid": Vector2i(15, 0), "size": Vector2i(3, 3)},
	{"id": 10, "type": "Empty", "grid": Vector2i(18, 1), "size": Vector2i(1, 1)},
	{"id": 11, "type": "Empty", "grid": Vector2i(19, 1), "size": Vector2i(1, 1)},
	{"id": 12, "type": "Boss", "grid": Vector2i(20, 0), "size": Vector2i(3, 3), "is_boss": true},
]

@export var map_viewport_path: NodePath
@export var map_content_path: NodePath
@export var grid_view_path: NodePath
@export var node_layer_path: NodePath

@onready var title_label: Label = $"../InfoPanel/PanelMargin/InfoLayout/HeaderRow/TitleLabel"
@onready var difficulty_label: Label = $"../InfoPanel/PanelMargin/InfoLayout/HeaderRow/DifficultyLabel"
@onready var status_label: Label = $"../InfoPanel/PanelMargin/InfoLayout/StatusLabel"
@onready var detail_label: Label = $"../InfoPanel/PanelMargin/InfoLayout/DetailLabel"
@onready var map_viewport: Control = get_node(map_viewport_path)
@onready var map_content: Control = get_node(map_content_path)
@onready var grid_view: Control = get_node(grid_view_path)
@onready var node_layer: Control = get_node(node_layer_path)

var node_views_by_id: Dictionary = {}
var node_order: Array[int] = []
var nodes_by_id: Dictionary = {}
var map_grid_size: Vector2i = Vector2i.ONE

func _ready() -> void:
	_create_path_data(DEFAULT_NODE_DESCRIPTORS)
	_build_node_views()
	_sync_run_data_metadata()

	if _apply_pending_combat_result():
		return

	_apply_progress_state()
	_refresh_view()
	call_deferred("_center_map_content")

func _create_path_data(descriptors: Array) -> void:
	nodes_by_id.clear()
	node_order.clear()
	map_grid_size = Vector2i.ONE
	for raw_descriptor in descriptors:
		var descriptor: Dictionary = raw_descriptor
		var grid_position: Vector2i = descriptor.get("grid", Vector2i.ZERO)
		var grid_size: Vector2i = descriptor.get("size", _default_grid_size_for_type(str(descriptor.get("type", DungeonNodeDataScript.TYPE_FIGHT))))
		var node := DungeonNodeDataScript.new(
			int(descriptor.get("id", -1)),
			str(descriptor.get("type", DungeonNodeDataScript.TYPE_FIGHT)),
			str(descriptor.get("enemy", "")),
			bool(descriptor.get("is_boss", false)),
			grid_position,
			grid_size
		)
		nodes_by_id[node.id] = node
		node_order.append(node.id)
		map_grid_size.x = max(map_grid_size.x, grid_position.x + grid_size.x)
		map_grid_size.y = max(map_grid_size.y, grid_position.y + grid_size.y)

	node_order.sort()
	for index in node_order.size():
		var node = nodes_by_id.get(node_order[index])
		if node == null:
			continue
		if index > 0:
			node.connected_node_ids.append(node_order[index - 1])
		if index < node_order.size() - 1:
			node.connected_node_ids.append(node_order[index + 1])

func _build_node_views() -> void:
	for child in node_layer.get_children():
		child.queue_free()

	node_views_by_id.clear()
	var map_size := Vector2(map_grid_size) * GRID_CELL_SIZE
	map_content.size = map_size
	node_layer.size = map_size
	grid_view.call("configure", map_grid_size.x, map_grid_size.y, GRID_CELL_SIZE)

	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		if node == null:
			continue
		var view: DungeonNodeView = DungeonNodeViewScript.new()
		view.name = "%sNode%s" % [node.node_type, node.id]
		view.configure(node, GRID_CELL_SIZE)
		node_layer.add_child(view)
		node_views_by_id[node.id] = view
		var callback := _on_node_pressed.bind(node.id)
		if not view.pressed.is_connected(callback):
			view.pressed.connect(callback)

func _sync_run_data_metadata() -> void:
	var run_data: Variant = _run_data()
	run_data.total_nodes = nodes_by_id.size()
	run_data.boss_node_index = _boss_node_id()

func _apply_pending_combat_result() -> bool:
	if not GameManager.has_pending_combat_result():
		return false

	var result: Variant = GameManager.consume_last_combat_result()
	var run_data: Variant = _run_data()
	run_data.register_combat_result(result)
	GameManager.emit_run_state()

	if not result.victory or result.is_boss:
		GameManager.call_deferred("go_to_scene", "run_summary")
		return true

	_apply_progress_state()
	_refresh_view()
	return false

func _apply_progress_state() -> void:
	var run_data: Variant = _run_data()
	var visited_ids: Array = run_data.get_visited_dungeon_node_ids()

	for raw_node in nodes_by_id.values():
		var node = raw_node
		if node == null:
			continue
		node.visited = visited_ids.has(node.id)
		node.revealed = node.visited or node.id == START_NODE_ID

	for raw_node in nodes_by_id.values():
		var node = raw_node
		if node == null or not node.visited:
			continue
		for connected_id in node.connected_node_ids:
			var connected_node = nodes_by_id.get(connected_id)
			if connected_node != null:
				connected_node.revealed = true

func _refresh_view() -> void:
	var run_data: Variant = _run_data()
	title_label.text = "Dungeon Map"
	difficulty_label.text = "Difficulty: %s" % GameManager.get_selected_difficulty_display_name()
	status_label.text = "Progress: %s / %s fights complete" % [
		run_data.fights_completed,
		_combat_node_count(),
	]

	var current_node_id := int(run_data.get_last_visited_dungeon_node_id())
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		var view: DungeonNodeView = node_views_by_id.get(node_id)
		if view != null:
			view.apply_state(node, node != null and node.id == current_node_id, _can_select_node(node))

	var next_node: Variant = _next_selectable_node()
	if next_node == null:
		detail_label.text = "No reachable node."
	else:
		detail_label.text = "Reachable: %s" % next_node.node_type

func _can_select_node(node: Variant) -> bool:
	if node == null or node.visited or not node.revealed:
		return false

	return node.id == START_NODE_ID or _has_visited_neighbor(node)

func _has_visited_neighbor(node: Variant) -> bool:
	for connected_id in node.connected_node_ids:
		var connected_node = nodes_by_id.get(connected_id)
		if connected_node != null and connected_node.visited:
			return true

	return false

func _next_selectable_node() -> Variant:
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		if _can_select_node(node):
			return node

	return null

func _on_node_pressed(node_id: int) -> void:
	var node = nodes_by_id.get(node_id)
	if not _can_select_node(node):
		return

	var event := DungeonNodeEventHelperScript.build_node_event(node)
	node_event_emitted.emit(event)
	var result := DungeonNodeEventHelperScript.process_node_event(node, GameManager, SoundManager)
	if bool(result.get(DungeonNodeEventHelperScript.RESULT_COMPLETION_DEFERRED, false)):
		return

	_complete_node_visit(node)

func _complete_node_visit(node: DungeonNodeData) -> void:
	var run_data: Variant = _run_data()
	run_data.mark_dungeon_node_visited(node.id)
	node_completed.emit(node.id, node.node_type)
	GameManager.emit_run_state()
	_apply_progress_state()
	_refresh_view()

func _center_map_content() -> void:
	var viewport_size := map_viewport.size
	var content_size := map_content.size * map_content.scale
	map_content.position = (viewport_size - content_size) * 0.5

func _run_data() -> Variant:
	if GameManager.current_run_data == null:
		GameManager.start_new_run(GameManager.get_selected_character_id(), GameManager.get_selected_difficulty_id())

	return GameManager.current_run_data

func _boss_node_id() -> int:
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		if node != null and (node.is_boss or node.node_type == DungeonNodeDataScript.TYPE_BOSS):
			return node.id

	return node_order[node_order.size() - 1] if not node_order.is_empty() else START_NODE_ID

func _combat_node_count() -> int:
	var count := 0
	for raw_node in nodes_by_id.values():
		var node = raw_node
		if node != null and (node.node_type == DungeonNodeDataScript.TYPE_FIGHT or node.node_type == DungeonNodeDataScript.TYPE_BOSS):
			count += 1

	return count

func _default_grid_size_for_type(node_type: String) -> Vector2i:
	if node_type == DungeonNodeDataScript.TYPE_EMPTY:
		return Vector2i.ONE

	return Vector2i(3, 3)
