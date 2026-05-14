## Controls generated dungeon map progression, node reveal state, completed combat results, and node event routing.
extends Node

signal node_event_emitted(event: Dictionary)
signal node_completed(node_id: int, node_type: String)

const DungeonNodeDataScript := preload("res://core/dungeon/dungeon_node_data.gd")
const DungeonNodeEventHelperScript := preload("res://core/dungeon/dungeon_node_event_helper.gd")
const DungeonFloorGeneratorScript := preload("res://core/dungeon/dungeon_floor_generator.gd")
const DungeonNodeViewScript := preload("res://scenes/dungeon/dungeon_node_view.gd")
const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")
const ResourceBarScript := preload("res://scenes/ui/common/resource_bar.gd")

const GRID_CELL_SIZE := 72.0
const START_NODE_ID := 0

@export var map_viewport_path: NodePath
@export var map_content_path: NodePath
@export var grid_view_path: NodePath
@export var node_layer_path: NodePath
@export var encounter_layer_path: NodePath

@onready var difficulty_label: Label = $"../InfoPanel/PanelMargin/InfoLayout/DifficultyLabel"
@onready var seed_label: Label = $"../InfoPanel/PanelMargin/InfoLayout/SeedLabel"
@onready var copy_seed_button: Button = $"../InfoPanel/PanelMargin/InfoLayout/CopySeedButton"
@onready var dungeon_health_bar: ResourceBarScript = $"../DungeonHotbar/ResourceBars/HealthBar"
@onready var dungeon_health_label: Label = $"../DungeonHotbar/ResourceBars/HealthBar/HealthValueLabel"
@onready var dungeon_ability_slots: Control = $"../DungeonHotbar/AbilitySlots"
@onready var dungeon_ability_buttons: Array[Button] = [
	$"../DungeonHotbar/AbilitySlots/AbilityButton1",
	$"../DungeonHotbar/AbilitySlots/AbilityButton2",
	$"../DungeonHotbar/AbilitySlots/AbilityButton3",
]
@onready var map_viewport: Control = get_node(map_viewport_path)
@onready var map_content: Control = get_node(map_content_path)
@onready var grid_view: Control = get_node(grid_view_path)
@onready var node_layer: Control = get_node(node_layer_path)
@onready var encounter_layer: Control = get_node(encounter_layer_path)

var node_views_by_id: Dictionary = {}
var node_order: Array[int] = []
var nodes_by_id: Dictionary = {}
var map_grid_size: Vector2i = Vector2i.ONE
var active_encounter_scene: Node = null

func _ready() -> void:
	var copy_seed_callback := Callable(self, "_on_copy_seed_button_pressed")
	if not copy_seed_button.pressed.is_connected(copy_seed_callback):
		copy_seed_button.pressed.connect(copy_seed_callback)

	_configure_dungeon_health_hover()
	_configure_dungeon_hotbar()
	_create_path_data(_generate_run_descriptors())
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
	var explicit_connections_by_id := {}
	var has_explicit_connections := false
	for raw_descriptor in descriptors:
		var descriptor: Dictionary = raw_descriptor
		var grid_position: Vector2i = descriptor.get("grid", Vector2i.ZERO)
		var grid_size: Vector2i = descriptor.get("size", _default_grid_size_for_type(str(descriptor.get("type", DungeonNodeDataScript.TYPE_FIGHT))))
		var node := DungeonNodeDataScript.new(
			int(descriptor.get("id", -1)),
			str(descriptor.get("type", DungeonNodeDataScript.TYPE_FIGHT)),
			str(descriptor.get("enemy", "")),
			_string_name_from_variant(descriptor.get("encounter_id", &"")),
			bool(descriptor.get("is_boss", false)),
			grid_position,
			grid_size
		)
		nodes_by_id[node.id] = node
		node_order.append(node.id)
		if descriptor.has("connections"):
			has_explicit_connections = true
			explicit_connections_by_id[node.id] = descriptor.get("connections", [])
		map_grid_size.x = max(map_grid_size.x, grid_position.x + grid_size.x)
		map_grid_size.y = max(map_grid_size.y, grid_position.y + grid_size.y)

	node_order.sort()
	if has_explicit_connections:
		_apply_explicit_connections(explicit_connections_by_id)
	else:
		_apply_linear_connections()

func _apply_explicit_connections(explicit_connections_by_id: Dictionary) -> void:
	for node_id in node_order:
		for raw_connected_id in explicit_connections_by_id.get(node_id, []):
			_connect_node_ids(node_id, int(raw_connected_id))

func _apply_linear_connections() -> void:
	for index in node_order.size():
		var node = nodes_by_id.get(node_order[index])
		if node == null:
			continue
		if index > 0:
			_connect_node_ids(node.id, node_order[index - 1])
		if index < node_order.size() - 1:
			_connect_node_ids(node.id, node_order[index + 1])

func _connect_node_ids(first_id: int, second_id: int) -> void:
	if first_id == second_id:
		return
	var first_node = nodes_by_id.get(first_id)
	var second_node = nodes_by_id.get(second_id)
	if first_node == null or second_node == null:
		return
	if not first_node.connected_node_ids.has(second_id):
		first_node.connected_node_ids.append(second_id)
	if not second_node.connected_node_ids.has(first_id):
		second_node.connected_node_ids.append(first_id)

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
	difficulty_label.text = "Difficulty: %s" % GameManager.get_selected_difficulty_display_name()
	seed_label.text = "Seed: %s" % run_data.dungeon_seed
	_refresh_dungeon_hotbar()

	var current_node_id := int(run_data.get_last_visited_dungeon_node_id())
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		var view: DungeonNodeView = node_views_by_id.get(node_id)
		if view != null:
			view.apply_state(node, node != null and node.id == current_node_id, _can_select_node(node))

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

# Copies the active run seed to the system clipboard.
func _on_copy_seed_button_pressed() -> void:
	DisplayServer.clipboard_set(str(_run_data().dungeon_seed))

func _configure_dungeon_hotbar() -> void:
	var profile: CombatantProfile = GameManager.get_selected_character_profile()
	var health_config: Resource = profile.health_bar if profile != null else null
	if health_config != null:
		dungeon_health_bar.configure_from_config(health_config)
	else:
		dungeon_health_bar.resource_name = "HP"
		dungeon_health_bar.display_reference_value = true

	dungeon_health_bar.bonus_label = ""
	dungeon_health_bar.fill_start_value = 0
	dungeon_health_bar.draw_text = false
	dungeon_health_bar.border_color = Color.TRANSPARENT
	dungeon_health_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	dungeon_ability_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_dungeon_hotbar()

func _configure_dungeon_health_hover() -> void:
	dungeon_health_label.visible = false
	NumberFontHelper.apply_to_label(dungeon_health_label)
	if not dungeon_health_bar.mouse_entered.is_connected(_on_dungeon_health_bar_mouse_entered):
		dungeon_health_bar.mouse_entered.connect(_on_dungeon_health_bar_mouse_entered)
	if not dungeon_health_bar.mouse_exited.is_connected(_on_dungeon_health_bar_mouse_exited):
		dungeon_health_bar.mouse_exited.connect(_on_dungeon_health_bar_mouse_exited)

func _refresh_dungeon_hotbar() -> void:
	_refresh_dungeon_health_bar()
	_refresh_dungeon_ability_slots()

func _refresh_dungeon_health_bar() -> void:
	var hp_snapshot: Dictionary = GameManager.get_run_player_hp_snapshot()
	var max_hp: int = max(int(hp_snapshot.get("max", 0)), 1)
	var current_hp: int = clamp(int(hp_snapshot.get("current", 0)), 0, max_hp)
	dungeon_health_bar.set_values(current_hp, max_hp, 0)
	dungeon_health_label.text = "%s/%s" % [current_hp, max_hp]

func _on_dungeon_health_bar_mouse_entered() -> void:
	dungeon_health_label.visible = true

func _on_dungeon_health_bar_mouse_exited() -> void:
	dungeon_health_label.visible = false

func _refresh_dungeon_ability_slots() -> void:
	var abilities: Array = GameManager.get_dungeon_abilities(dungeon_ability_buttons.size())
	for index in dungeon_ability_buttons.size():
		var button: Button = dungeon_ability_buttons[index]
		if index >= abilities.size():
			button.text = ""
			button.tooltip_text = ""
			button.icon = null
			button.disabled = true
			continue

		var ability := abilities[index] as Resource
		if ability == null:
			button.text = ""
			button.tooltip_text = ""
			button.icon = null
			button.disabled = true
			continue

		button.text = _dungeon_ability_label(ability)
		button.tooltip_text = _dungeon_ability_tooltip(ability)
		button.icon = ability.get("icon") as Texture2D
		button.disabled = not bool(ability.get("enabled"))

func _dungeon_ability_label(ability: Resource) -> String:
	if ability == null:
		return ""
	if ability.has_method("label_text"):
		return str(ability.call("label_text"))

	var hotbar_label := str(ability.get("hotbar_label")).strip_edges()
	if not hotbar_label.is_empty():
		return hotbar_label

	var display_name := str(ability.get("display_name")).strip_edges()
	if not display_name.is_empty():
		return display_name.substr(0, 1).to_upper()

	return "?"

func _dungeon_ability_tooltip(ability: Resource) -> String:
	if ability == null:
		return ""

	var display_name := str(ability.get("display_name")).strip_edges()
	var description := str(ability.get("description")).strip_edges()
	if description.is_empty():
		return display_name

	return "%s\n%s" % [display_name, description]

func _on_node_pressed(node_id: int) -> void:
	var node = nodes_by_id.get(node_id)
	if not _can_select_node(node):
		return

	var event := DungeonNodeEventHelperScript.build_node_event(node)
	node_event_emitted.emit(event)
	if node.node_type == DungeonNodeDataScript.TYPE_ENCOUNTER:
		_start_encounter_node(node)
		return

	var result := DungeonNodeEventHelperScript.process_node_event(node, GameManager, SoundManager)
	if bool(result.get(DungeonNodeEventHelperScript.RESULT_COMPLETION_DEFERRED, false)):
		return
	if _run_data().has_ended():
		return

	_complete_node_visit(node)

func _start_encounter_node(node: DungeonNodeData) -> void:
	if node == null:
		return
	if not GameManager.advance_run_time(RunData.NODE_TRAVEL_TIME_SECONDS):
		return

	var encounter_data: Resource = GameManager.get_dungeon_encounter(node.encounter_id)
	var encounter_scene: PackedScene = GameManager.get_dungeon_encounter_scene(node.encounter_id)
	if encounter_data == null or encounter_scene == null:
		push_warning("Dungeon encounter %s could not be resolved." % node.encounter_id)
		_complete_node_visit(node)
		return

	_clear_active_encounter_scene()
	active_encounter_scene = encounter_scene.instantiate()
	encounter_layer.visible = true
	encounter_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	encounter_layer.add_child(active_encounter_scene)

	if active_encounter_scene.has_signal("encounter_finished"):
		active_encounter_scene.connect("encounter_finished", Callable(self, "_on_encounter_finished").bind(node.id))
	else:
		push_warning("Dungeon encounter scene %s does not emit encounter_finished." % active_encounter_scene.name)

	if active_encounter_scene.has_method("setup"):
		active_encounter_scene.call("setup", encounter_data, {
			"node_id": node.id,
			"encounter_id": node.encounter_id,
			"floor_layer": _run_data().dungeon_floor_layer,
		})

func _on_encounter_finished(result: Dictionary, node_id: int) -> void:
	var node = nodes_by_id.get(node_id)
	if node == null:
		_clear_active_encounter_scene()
		return

	var result_mode := str(result.get("mode", "complete"))
	if result_mode == "complete":
		GameManager.apply_dungeon_encounter_result(node.encounter_id, result)
	_clear_active_encounter_scene()
	if result_mode != "complete" or _run_data().has_ended():
		return

	_complete_node_visit(node)

func _clear_active_encounter_scene() -> void:
	if active_encounter_scene != null:
		active_encounter_scene.queue_free()
		active_encounter_scene = null
	encounter_layer.visible = false
	encounter_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func _generate_run_descriptors() -> Array:
	var run_data: Variant = _run_data()
	if run_data.dungeon_node_descriptors.is_empty():
		run_data.dungeon_node_descriptors = DungeonFloorGeneratorScript.generate_floor(
			run_data.dungeon_seed,
			run_data.dungeon_floor_layer,
			run_data.selected_difficulty,
			GameManager.DEFAULT_DUNGEON_GENERATION_CONFIG,
			GameManager.DEFAULT_DUNGEON_ENCOUNTER_POOL
		)

	return run_data.dungeon_node_descriptors.duplicate(true)

func _boss_node_id() -> int:
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		if node != null and (node.is_boss or node.node_type == DungeonNodeDataScript.TYPE_BOSS):
			return node.id

	return node_order[node_order.size() - 1] if not node_order.is_empty() else START_NODE_ID

func _default_grid_size_for_type(node_type: String) -> Vector2i:
	if node_type == DungeonNodeDataScript.TYPE_EMPTY:
		return Vector2i.ONE

	return Vector2i(3, 3)

func _string_name_from_variant(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)

	return &""
