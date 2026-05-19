## Controls generated dungeon map progression, node reveal state, completed combat results, and node event routing.
extends Node

signal node_event_emitted(event: Dictionary)
signal haven_node_entered(node_id: int)

const DungeonNodeDataScript := preload("res://core/dungeon/dungeon_node_data.gd")
const DungeonNodeEventHelperScript := preload("res://core/dungeon/dungeon_node_event_helper.gd")
const DungeonMapPawnViewScript := preload("res://scenes/dungeon/dungeon_map_pawn_view.gd")
const DungeonNodeViewScript := preload("res://scenes/dungeon/dungeon_node_view.gd")
const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")
const ResourceBarScript := preload("res://scenes/ui/common/resource_bar.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")

const GRID_CELL_SIZE := 72.0
const START_NODE_ID := 0

@export var map_viewport_path: NodePath
@export var map_content_path: NodePath
@export var grid_view_path: NodePath
@export var node_layer_path: NodePath
@export var pawn_layer_path: NodePath = ^"../MapViewport/MapContent/PawnLayer"
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
@onready var pawn_layer: Control = _resolve_pawn_layer()
@onready var encounter_layer: Control = get_node(encounter_layer_path)

var node_views_by_id: Dictionary = {}
var pawn_views_by_id: Dictionary = {}
var node_order: Array[int] = []
var nodes_by_id: Dictionary = {}
var map_grid_size: Vector2i = Vector2i.ONE
var active_encounter_scene: Node = null
var active_encounter_node_id: int = -1
var active_encounter_pawn_id: String = ""
var has_emitted_initial_haven_entry: bool = false

func _ready() -> void:
	if GameManager.has_active_run():
		GameManager.play_run_music(false)
	if not NetworkManager.authoritative_snapshot_received.is_connected(_on_authoritative_snapshot_received):
		NetworkManager.authoritative_snapshot_received.connect(_on_authoritative_snapshot_received)
	var copy_seed_callback := Callable(self, "_on_copy_seed_button_pressed")
	if not copy_seed_button.pressed.is_connected(copy_seed_callback):
		copy_seed_button.pressed.connect(copy_seed_callback)

	_configure_dungeon_health_hover()
	_configure_dungeon_hotbar()
	_create_path_data(_generate_run_descriptors())
	_build_node_views()
	if NetworkManager.is_authority():
		_sync_run_data_metadata()

	if NetworkManager.is_authority() and _apply_pending_combat_result():
		return

	_apply_progress_state()
	_refresh_view()
	_sync_active_encounter_from_snapshot()
	_emit_initial_haven_entry()
	call_deferred("_center_map_content")

func _create_path_data(descriptors: Array) -> void:
	nodes_by_id.clear()
	node_order.clear()
	map_grid_size = Vector2i.ONE
	var explicit_connections_by_id := {}
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			push_error("DungeonController received a non-dictionary node descriptor.")
			return
		var descriptor: Dictionary = raw_descriptor
		if not descriptor.has("connections") or not (descriptor.get("connections") is Array):
			push_error("Dungeon node descriptor %s is missing explicit connections." % int(descriptor.get("id", -1)))
			return
		var grid_position: Vector2i = _vector2i_value(descriptor.get("grid", Vector2i.ZERO))
		var grid_size: Vector2i = _vector2i_value(descriptor.get("size", _default_grid_size_for_type(str(descriptor.get("type", DungeonNodeDataScript.TYPE_FIGHT)))))
		var node := DungeonNodeDataScript.new(
			int(descriptor.get("id", -1)),
			str(descriptor.get("type", DungeonNodeDataScript.TYPE_FIGHT)),
			_enemy_instances_from_descriptor(descriptor),
			ValueReaderScript.string_name_from_variant(descriptor.get("encounter_id", &"")),
			ValueReaderScript.string_name_from_variant(descriptor.get("combat_encounter_id", &"")),
			str(descriptor.get("combat_encounter_profile_path", "")),
			bool(descriptor.get("is_boss", false)),
			grid_position,
			grid_size
		)
		nodes_by_id[node.id] = node
		node_order.append(node.id)
		explicit_connections_by_id[node.id] = descriptor.get("connections", [])
		map_grid_size.x = max(map_grid_size.x, grid_position.x + grid_size.x)
		map_grid_size.y = max(map_grid_size.y, grid_position.y + grid_size.y)

	node_order.sort()
	_apply_explicit_connections(explicit_connections_by_id)

func _apply_explicit_connections(explicit_connections_by_id: Dictionary) -> void:
	for node_id in node_order:
		for raw_connected_id in explicit_connections_by_id.get(node_id, []):
			_connect_node_ids(node_id, int(raw_connected_id))

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
	if pawn_layer != null:
		for child in pawn_layer.get_children():
			child.queue_free()

	node_views_by_id.clear()
	pawn_views_by_id.clear()
	var map_size := Vector2(map_grid_size) * GRID_CELL_SIZE
	map_content.size = map_size
	node_layer.size = map_size
	if pawn_layer != null:
		pawn_layer.size = map_size
		pawn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	_build_pawn_views()

func _build_pawn_views() -> void:
	if pawn_layer == null:
		return

	var dungeon_snapshot: Dictionary = _dungeon_snapshot_for_view()
	var pawn_snapshots: Dictionary = dungeon_snapshot.get("pawns", {})
	for raw_pawn_id in dungeon_snapshot.get("active_pawn_ids", []):
		var pawn_id := str(raw_pawn_id)
		var pawn_snapshot: Dictionary = pawn_snapshots.get(pawn_id, {})
		if pawn_snapshot.is_empty():
			continue

		var view: Control = DungeonMapPawnViewScript.new() as Control
		view.name = _pawn_view_name(pawn_id)
		pawn_layer.add_child(view)
		pawn_views_by_id[pawn_id] = view
		var node: DungeonNodeData = nodes_by_id.get(int(pawn_snapshot.get("current_node_id", -1))) as DungeonNodeData
		view.call("configure", pawn_snapshot, node, GRID_CELL_SIZE)

func _sync_run_data_metadata() -> void:
	var run_data: Variant = _run_data_for_action()
	DungeonManager.configure_map_metadata(run_data, nodes_by_id.size(), _boss_node_id())
	if not DungeonManager.has_map_pawns(run_data):
		DungeonManager.initialize_map_state_for_run(run_data, START_NODE_ID)

func _apply_pending_combat_result() -> bool:
	if not GameManager.has_pending_combat_result():
		return false

	var result: Variant = GameManager.consume_last_combat_result()
	GameManager.emit_run_state()

	if not result.victory or result.is_boss:
		NetworkManager.call_deferred("request_route", "run_summary")
		return true

	_apply_progress_state()
	_refresh_view()
	return false

func _apply_progress_state() -> void:
	var dungeon_snapshot: Dictionary = _dungeon_snapshot_for_view()
	var visited_ids: Array = dungeon_snapshot.get("visited_node_ids", [])
	var revealed_ids: Array = dungeon_snapshot.get("revealed_node_ids", [])
	var resolved_ids: Array = dungeon_snapshot.get("resolved_node_ids", [])

	for raw_node in nodes_by_id.values():
		var node = raw_node
		if node == null:
			continue
		node.visited = visited_ids.has(node.id)
		node.resolved = resolved_ids.has(node.id)
		node.revealed = revealed_ids.has(node.id) or node.visited or node.id == START_NODE_ID

func _refresh_view() -> void:
	var dungeon_snapshot: Dictionary = _dungeon_snapshot_for_view()
	difficulty_label.text = "Difficulty: %s" % GameManager.get_selected_difficulty_display_name()
	seed_label.text = "Seed: %s" % str(dungeon_snapshot.get("seed", ""))
	_refresh_dungeon_hotbar()

	var current_node_id := int(dungeon_snapshot.get("current_node_id", -1))
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		var view: DungeonNodeView = node_views_by_id.get(node_id)
		if view != null:
			view.apply_state(node, node != null and node.id == current_node_id, _can_select_node(node))
	_refresh_pawn_views(dungeon_snapshot)

func _refresh_pawn_views(dungeon_snapshot: Dictionary) -> void:
	if pawn_layer == null:
		return

	var active_pawn_lookup: Dictionary = {}
	var pawn_snapshots: Dictionary = dungeon_snapshot.get("pawns", {})
	for raw_pawn_id in dungeon_snapshot.get("active_pawn_ids", []):
		var pawn_id := str(raw_pawn_id)
		active_pawn_lookup[pawn_id] = true
		var pawn_snapshot: Dictionary = pawn_snapshots.get(pawn_id, {})
		if pawn_snapshot.is_empty():
			continue

		var view: Control = pawn_views_by_id.get(pawn_id, null) as Control
		if view == null:
			view = DungeonMapPawnViewScript.new() as Control
			view.name = _pawn_view_name(pawn_id)
			pawn_layer.add_child(view)
			pawn_views_by_id[pawn_id] = view

		var node: DungeonNodeData = nodes_by_id.get(int(pawn_snapshot.get("current_node_id", -1))) as DungeonNodeData
		view.call("apply_pawn_state", pawn_snapshot, node, GRID_CELL_SIZE)

	for raw_view_pawn_id in pawn_views_by_id.keys():
		var view_pawn_id := str(raw_view_pawn_id)
		if active_pawn_lookup.has(view_pawn_id):
			continue

		var stale_view: Node = pawn_views_by_id.get(view_pawn_id, null) as Node
		if stale_view != null:
			stale_view.queue_free()
		pawn_views_by_id.erase(view_pawn_id)

func _on_authoritative_snapshot_received(_snapshot: Dictionary) -> void:
	_apply_progress_state()
	_refresh_view()
	_sync_active_encounter_from_snapshot()

func _sync_active_encounter_from_snapshot() -> void:
	var dungeon_snapshot: Dictionary = _dungeon_snapshot_for_view()
	var active_event: Dictionary = dungeon_snapshot.get("active_event", {})
	if active_event.is_empty():
		if active_encounter_scene != null:
			_clear_active_encounter_scene()
		return
	if str(active_event.get("type", "")) != "encounter":
		return

	var node_id: int = int(active_event.get("node_id", -1))
	var node: DungeonNodeData = nodes_by_id.get(node_id) as DungeonNodeData
	if node == null:
		push_error("Active encounter references missing dungeon node %s." % node_id)
		return
	active_encounter_pawn_id = str(active_event.get("pawn_id", ""))
	if active_encounter_pawn_id.is_empty():
		push_error("Active encounter is missing its owning pawn id.")
		return
	if active_encounter_scene != null and active_encounter_node_id == node_id:
		_apply_encounter_interactivity()
		return
	_start_encounter_node(node, false, active_encounter_pawn_id)

func _apply_encounter_interactivity() -> void:
	if active_encounter_scene == null:
		return
	var active_event: Dictionary = _dungeon_snapshot_for_view().get("active_event", {})
	var can_interact: bool = int(active_event.get("owner_peer_id", 1)) == NetworkManager.local_peer_id()
	if active_encounter_scene.has_method("set_interactive"):
		active_encounter_scene.call("set_interactive", can_interact)

func _dungeon_snapshot_for_view() -> Dictionary:
	if NetworkManager.is_client() and not NetworkManager.last_authoritative_snapshot.is_empty():
		var dungeon_snapshot: Dictionary = NetworkManager.last_authoritative_snapshot.get("dungeon", {})
		if not dungeon_snapshot.is_empty():
			return dungeon_snapshot
	return GameManager.get_dungeon_snapshot()

func _dungeon_snapshot_for_local_input() -> Dictionary:
	var dungeon_snapshot := _dungeon_snapshot_for_view().duplicate(true)
	dungeon_snapshot["selected_pawn_id"] = _local_input_pawn_id(dungeon_snapshot)
	return dungeon_snapshot

func _local_input_pawn_id(dungeon_snapshot: Dictionary) -> String:
	var pawns: Dictionary = dungeon_snapshot.get("pawns", {})
	for raw_pawn_id in dungeon_snapshot.get("active_pawn_ids", []):
		var pawn_id := str(raw_pawn_id)
		var pawn: Dictionary = pawns.get(pawn_id, {})
		if int(pawn.get("owner_peer_id", 1)) == NetworkManager.local_peer_id():
			return pawn_id
	return str(dungeon_snapshot.get("selected_pawn_id", ""))

func _can_select_node(node: Variant) -> bool:
	if node == null or not node.revealed:
		return false
	var dungeon_snapshot: Dictionary = _dungeon_snapshot_for_local_input()
	if node.id == int(dungeon_snapshot.get("current_node_id", -1)):
		return false

	return DungeonManager.can_request_selected_pawn_travel_snapshot(dungeon_snapshot, node.id)

# Copies the active run seed to the system clipboard.
func _on_copy_seed_button_pressed() -> void:
	DisplayServer.clipboard_set(str(_dungeon_snapshot_for_view().get("seed", "")))

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

	var dungeon_snapshot: Dictionary = _dungeon_snapshot_for_local_input()
	var pawn_id: String = str(dungeon_snapshot.get("selected_pawn_id", ""))
	if pawn_id.is_empty():
		return

	NetworkManager.request_pawn_travel(pawn_id, node_id)

func _emit_initial_haven_entry() -> void:
	if not NetworkManager.is_authority():
		return
	if has_emitted_initial_haven_entry:
		return

	var run_data: Variant = _run_data_for_action()
	var pawn: Variant = DungeonManager.get_selected_pawn(run_data)
	if pawn == null:
		return

	var node: DungeonNodeData = nodes_by_id.get(int(pawn.current_node_id)) as DungeonNodeData
	if node == null or node.node_type != DungeonNodeDataScript.TYPE_HAVEN:
		return

	has_emitted_initial_haven_entry = true
	_emit_node_entered(node)
	haven_node_entered.emit(node.id)
	_apply_progress_state()
	_refresh_view()

func _emit_node_entered(node: DungeonNodeData) -> void:
	node_event_emitted.emit(DungeonNodeEventHelperScript.build_node_event(node))

func _start_encounter_node(node: DungeonNodeData, charge_travel_time: bool = true, pawn_id: String = "") -> void:
	if node == null:
		return
	if pawn_id.is_empty():
		push_error("Cannot start dungeon encounter node %s without an owning pawn id." % node.id)
		return
	if charge_travel_time and not GameManager.advance_run_time(DungeonManager.NODE_TRAVEL_TIME):
		return

	var encounter_data: Resource = GameManager.get_dungeon_encounter(node.encounter_id)
	var encounter_scene: PackedScene = GameManager.get_dungeon_encounter_scene(node.encounter_id)
	if encounter_data == null or encounter_scene == null:
		push_error("Dungeon encounter %s could not be resolved." % node.encounter_id)
		return

	_clear_active_encounter_scene()
	active_encounter_node_id = node.id
	active_encounter_pawn_id = pawn_id
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
			"floor_layer": int(_dungeon_snapshot_for_view().get("floor_layer", 1)),
		})
	_apply_encounter_interactivity()

func _on_encounter_finished(result: Dictionary, node_id: int) -> void:
	var node = nodes_by_id.get(node_id)
	if node == null:
		_clear_active_encounter_scene()
		return

	var result_mode := str(result.get("mode", "complete"))
	if result_mode != "complete":
		push_warning("Unsupported dungeon encounter result mode: %s. Keeping encounter active so event-locked pawns can still resolve it." % result_mode)
		return
	if active_encounter_pawn_id.is_empty():
		push_error("Cannot resolve dungeon encounter node %s without an owning pawn id." % node.id)
		return

	var manager_result := result.duplicate(true)
	manager_result["node_id"] = node.id
	manager_result["pawn_id"] = active_encounter_pawn_id
	manager_result["encounter_id"] = String(node.encounter_id)
	NetworkManager.request_encounter_choice(manager_result)

func _clear_active_encounter_scene() -> void:
	if active_encounter_scene != null:
		active_encounter_scene.queue_free()
		active_encounter_scene = null
	active_encounter_node_id = -1
	active_encounter_pawn_id = ""
	encounter_layer.visible = false
	encounter_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _center_map_content() -> void:
	var viewport_size := map_viewport.size
	var content_size := map_content.size * map_content.scale
	map_content.position = (viewport_size - content_size) * 0.5

func _run_data_for_action() -> Variant:
	if not NetworkManager.is_authority():
		return GameManager.get_current_run_reference()
	if not GameManager.has_current_run_data():
		GameManager.start_new_run(GameManager.get_selected_character_id(), GameManager.get_selected_difficulty_id())

	return GameManager.get_current_run_reference()

func _resolve_pawn_layer() -> Control:
	if not pawn_layer_path.is_empty():
		var configured_layer: Control = get_node_or_null(pawn_layer_path) as Control
		if configured_layer != null:
			return configured_layer

	return get_node_or_null("../MapViewport/MapContent/PawnLayer") as Control

func _generate_run_descriptors() -> Array:
	var snapshot_descriptors: Array = _dungeon_snapshot_for_view().get("descriptors", [])
	if not snapshot_descriptors.is_empty():
		return snapshot_descriptors.duplicate(true)

	var run_data: Variant = _run_data_for_action()
	if run_data.dungeon_node_descriptors.is_empty():
		DungeonManager.initialize_dungeon_for_run(run_data)
	if not DungeonManager.has_map_pawns(run_data):
		DungeonManager.initialize_map_state_for_run(run_data, START_NODE_ID)

	return run_data.dungeon_node_descriptors.duplicate(true)

func _boss_node_id() -> int:
	for node_id in node_order:
		var node = nodes_by_id.get(node_id)
		if node != null and (node.is_boss or node.node_type == DungeonNodeDataScript.TYPE_BOSS):
			return node.id

	return node_order[node_order.size() - 1] if not node_order.is_empty() else START_NODE_ID

func _pawn_view_name(pawn_id: String) -> String:
	var normalized := pawn_id.strip_edges().replace(".", "_").replace(" ", "_")
	if normalized.is_empty():
		normalized = "pawn"

	return "PawnMarker_%s" % normalized

func _default_grid_size_for_type(node_type: String) -> Vector2i:
	if node_type == DungeonNodeDataScript.TYPE_EMPTY:
		return Vector2i.ONE

	return Vector2i(3, 3)

func _vector2i_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO

func _enemy_instances_from_descriptor(descriptor: Dictionary) -> Array[Dictionary]:
	var enemy_instances: Array[Dictionary] = []
	var raw_enemy_instances: Variant = descriptor.get("enemy_instances", [])
	if not (raw_enemy_instances is Array):
		return enemy_instances

	for raw_enemy_instance in raw_enemy_instances:
		if raw_enemy_instance is Dictionary:
			enemy_instances.append(raw_enemy_instance.duplicate(true))

	return enemy_instances
