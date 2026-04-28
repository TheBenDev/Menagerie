extends Node

const DungeonNodeDataScript := preload("res://scripts/dungeon/dungeon_node_data.gd")
const DungeonNodeViewScript := preload("res://scripts/dungeon/dungeon_node_view.gd")

@export var node_container_path: NodePath

@onready var title_label: Label = $"../MarginContainer/Layout/HeaderRow/TitleLabel"
@onready var difficulty_label: Label = $"../MarginContainer/Layout/HeaderRow/DifficultyLabel"
@onready var status_label: Label = $"../MarginContainer/Layout/StatusLabel"
@onready var detail_label: Label = $"../MarginContainer/Layout/DetailLabel"
@onready var node_container: HBoxContainer = get_node(node_container_path)

var node_views: Array = []
var nodes_by_id: Dictionary = {}

func _ready() -> void:
	_collect_node_views()
	_create_path_data()
	_sync_run_data_metadata()
	_connect_node_views()

	if _apply_pending_combat_result():
		return

	_apply_progress_state()
	_refresh_view()

func _collect_node_views() -> void:
	node_views.clear()
	for child in node_container.get_children():
		if child.get_script() == DungeonNodeViewScript:
			node_views.append(child)

	node_views.sort_custom(_sort_node_views)

func _create_path_data() -> void:
	nodes_by_id.clear()
	for view in node_views:
		var node := DungeonNodeDataScript.new(
			view.node_id,
			view.node_type,
			view.enemy_profile_path,
			view.is_boss
		)
		nodes_by_id[node.id] = node

	for index in node_views.size():
		var view: Variant = node_views[index]
		var node = nodes_by_id.get(view.node_id)
		if node == null:
			continue

		if index > 0:
			node.connected_node_ids.append(node_views[index - 1].node_id)
		if index < node_views.size() - 1:
			node.connected_node_ids.append(node_views[index + 1].node_id)

func _sync_run_data_metadata() -> void:
	var run_data: Variant = _run_data()
	run_data.total_nodes = node_views.size()
	run_data.boss_node_index = _boss_node_id()

func _connect_node_views() -> void:
	for view in node_views:
		var callback := _on_node_pressed.bind(view.node_id)
		if not view.pressed.is_connected(callback):
			view.pressed.connect(callback)

func _apply_pending_combat_result() -> bool:
	if GameManager.last_combat_result == null:
		return false

	var result: Variant = GameManager.consume_last_combat_result()
	var run_data: Variant = _run_data()
	run_data.register_combat_result(result)
	GameManager.emit_run_state()

	if not result.victory or result.is_boss:
		GameManager.call_deferred("go_to_run_summary")
		return true

	return false

func _apply_progress_state() -> void:
	var run_data: Variant = _run_data()
	var current_node_id: int = max(int(run_data.current_node_index), 0)

	for raw_node in nodes_by_id.values():
		var node = raw_node
		if node == null:
			continue
		node.visited = node.id <= current_node_id
		node.revealed = node.visited

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
	title_label.text = "Dungeon"
	difficulty_label.text = "Difficulty: %s" % GameManager.get_selected_difficulty_display_name()
	status_label.text = "Progress: %s / %s fights complete" % [
		run_data.fights_completed,
		max(run_data.total_nodes - 1, 0),
	]

	for view in node_views:
		var node = nodes_by_id.get(view.node_id)
		view.apply_state(node, node != null and node.id == run_data.current_node_index, _can_select_node(node))

	var next_node: Variant = _next_selectable_node()
	if next_node == null:
		detail_label.text = "No reachable node."
	else:
		detail_label.text = "Next: %s" % next_node.node_type

func _can_select_node(node: Variant) -> bool:
	if node == null or node.visited or not node.revealed:
		return false

	return _has_visited_neighbor(node)

func _has_visited_neighbor(node: Variant) -> bool:
	for connected_id in node.connected_node_ids:
		var connected_node = nodes_by_id.get(connected_id)
		if connected_node != null and connected_node.visited:
			return true

	return false

func _next_selectable_node() -> Variant:
	for view in node_views:
		var node = nodes_by_id.get(view.node_id)
		if _can_select_node(node):
			return node

	return null

func _on_node_pressed(node_id: int) -> void:
	var node = nodes_by_id.get(node_id)
	if not _can_select_node(node):
		return

	if node.node_type == "Fight" or node.node_type == "Boss":
		GameManager.start_combat(node.id, node.node_type, node.enemy_profile, node.is_boss)

func _run_data() -> Variant:
	if GameManager.current_run_data == null:
		GameManager.start_new_run(GameManager.selected_character, GameManager.selected_difficulty)

	return GameManager.current_run_data

func _boss_node_id() -> int:
	for view in node_views:
		if view.is_boss or view.node_type == "Boss":
			return view.node_id

	return max(node_views.size() - 1, 0)

func _sort_node_views(a: Variant, b: Variant) -> bool:
	return a.node_id < b.node_id
