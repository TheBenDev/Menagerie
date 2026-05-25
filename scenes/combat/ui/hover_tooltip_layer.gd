## Canvas layer that owns dynamic hover tooltip instances and positions them near the mouse.
class_name HoverTooltipLayer
extends CanvasLayer

const HoverInfoKeywordResolverScript := preload("res://core/hover_info/hover_info_keyword_resolver.gd")

const HOVER_INFO_META := &"hover_info_data"
const CURSOR_OFFSET := Vector2(24.0, 24.0)
const PANEL_GAP := 8.0
const VIEWPORT_MARGIN := 8.0

@export var main_panel_scene: PackedScene = preload("res://scenes/combat/ui/HoverInfoPanel.tscn")
@export var keyword_panel_scene: PackedScene = preload("res://scenes/combat/ui/HoverKeywordPanel.tscn")
@export var tooltip_root_path: NodePath = ^"TooltipRoot"
@export_range(0.0, 5.0, 0.05, "or_greater") var hover_delay_seconds: float = 1.0

@onready var tooltip_root: Control = get_node(tooltip_root_path) as Control

var active_source: Object = null
var pending_source: Object = null
var current_info: Resource = null
var main_panel: Control = null
var keyword_panels: Array[Control] = []
var hover_delay_timer: SceneTreeTimer = null
var hover_request_id: int = 0
var last_formula_modifier_pressed: bool = false

func _ready() -> void:
	if tooltip_root != null:
		tooltip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_formula_modifier_pressed = _is_formula_modifier_pressed()
	clear()

func _process(_delta: float) -> void:
	if pending_source != null and not is_instance_valid(pending_source):
		clear()
		return
	if main_panel == null:
		return
	if active_source != null and not is_instance_valid(active_source):
		clear()
		return

	_refresh_if_formula_modifier_changed()
	_position_panels()

func bind_source(source: Control) -> void:
	if source == null:
		return

	source.tooltip_text = ""
	var entered_callback := _on_source_mouse_entered.bind(source)
	if not source.mouse_entered.is_connected(entered_callback):
		source.mouse_entered.connect(entered_callback)

	var exited_callback := _on_source_mouse_exited.bind(source)
	if not source.mouse_exited.is_connected(exited_callback):
		source.mouse_exited.connect(exited_callback)

func show_for_source(source: Object) -> void:
	_cancel_pending_hover()
	_show_for_source_now(source)

func show_for_source_delayed(source: Object) -> void:
	_cancel_pending_hover()
	_clear_visible_hover()
	if source == null:
		return

	pending_source = source
	hover_request_id += 1
	var request_id := hover_request_id
	if hover_delay_seconds <= 0.0:
		_on_hover_delay_elapsed(request_id)
		return

	hover_delay_timer = get_tree().create_timer(hover_delay_seconds, true, false, true)
	hover_delay_timer.timeout.connect(_on_hover_delay_elapsed.bind(request_id))

func _show_for_source_now(source: Object) -> void:
	var info := _hover_info_from_source(source)
	if not _hover_info_has_content(info):
		clear()
		return

	active_source = source
	show_hover_info(info)

func show_hover_info(info: Resource) -> void:
	_cancel_pending_hover()
	_free_panels()
	current_info = info
	if info == null or tooltip_root == null:
		return

	main_panel = main_panel_scene.instantiate() as Control
	tooltip_root.add_child(main_panel)
	main_panel.call("set_hover_info", info)

	var keyword_infos := HoverInfoKeywordResolverScript.keyword_infos_for_ids(_keyword_ids_from_info(info))
	for keyword_info in keyword_infos:
		var keyword_panel := keyword_panel_scene.instantiate() as Control
		tooltip_root.add_child(keyword_panel)
		keyword_panel.call("set_keyword_info", keyword_info)
		keyword_panels.append(keyword_panel)

	call_deferred("_position_panels")

func clear() -> void:
	_cancel_pending_hover()
	_clear_visible_hover()

func _clear_visible_hover() -> void:
	active_source = null
	current_info = null
	_free_panels()

func _hover_info_from_source(source: Object) -> Resource:
	if source == null:
		return null

	if source.has_method("get_hover_info"):
		var method_info = source.call("get_hover_info")
		if method_info != null:
			return method_info

	if source.has_meta(HOVER_INFO_META):
		return source.get_meta(HOVER_INFO_META)

	return null

func _hover_info_has_content(info) -> bool:
	if info == null or not info is Object:
		return false
	if info.has_method("has_content"):
		return bool(info.call("has_content"))

	return (
		not str(info.get("title")).strip_edges().is_empty()
		or not str(info.get("subtitle")).strip_edges().is_empty()
		or not str(info.get("description")).strip_edges().is_empty()
		or not str(info.get("footer")).strip_edges().is_empty()
	)

func _keyword_ids_from_info(info) -> Array[StringName]:
	var keyword_ids: Array[StringName] = []
	if info == null:
		return keyword_ids

	var raw_keyword_ids: Variant = info.get("keyword_ids")
	if raw_keyword_ids is Array:
		for raw_keyword_id in raw_keyword_ids:
			var keyword_id := StringName(str(raw_keyword_id))
			if keyword_id != &"":
				keyword_ids.append(keyword_id)
	return keyword_ids

func _position_panels() -> void:
	if tooltip_root == null or main_panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	var main_size := _fit_panel(main_panel)
	var main_position := mouse_position + CURSOR_OFFSET

	if main_position.y + main_size.y + VIEWPORT_MARGIN > viewport_size.y:
		main_position.y = mouse_position.y - CURSOR_OFFSET.y - main_size.y
	if main_position.x + main_size.x + VIEWPORT_MARGIN > viewport_size.x:
		main_position.x = mouse_position.x - CURSOR_OFFSET.x - main_size.x

	main_position = _clamped_position(main_position, main_size, viewport_size)
	main_panel.position = main_position
	_position_keyword_panels(main_position, main_size, viewport_size)

func _position_keyword_panels(main_position: Vector2, main_size: Vector2, viewport_size: Vector2) -> void:
	if keyword_panels.is_empty():
		return

	var stack_width := 0.0
	var stack_height := 0.0
	var panel_sizes: Array[Vector2] = []
	for panel in keyword_panels:
		var panel_size := _fit_panel(panel)
		panel_sizes.append(panel_size)
		stack_width = max(stack_width, panel_size.x)
		stack_height += panel_size.y

	stack_height += PANEL_GAP * float(max(keyword_panels.size() - 1, 0))
	var stack_position := Vector2(main_position.x + main_size.x + PANEL_GAP, main_position.y)
	if stack_position.x + stack_width + VIEWPORT_MARGIN > viewport_size.x:
		stack_position.x = main_position.x - stack_width - PANEL_GAP

	stack_position = _clamped_position(stack_position, Vector2(stack_width, stack_height), viewport_size)
	var panel_y := stack_position.y
	for index in keyword_panels.size():
		var panel := keyword_panels[index]
		var panel_size := panel_sizes[index]
		panel.position = Vector2(stack_position.x, panel_y)
		panel_y += panel_size.y + PANEL_GAP

func _fit_panel(panel: Control) -> Vector2:
	if panel == null:
		return Vector2.ZERO

	panel.reset_size()
	var minimum_size := panel.get_combined_minimum_size()
	var target_size := Vector2(
		max(minimum_size.x, panel.custom_minimum_size.x),
		max(minimum_size.y, panel.custom_minimum_size.y)
	)
	panel.size = target_size
	return target_size

func _clamped_position(position: Vector2, panel_size: Vector2, viewport_size: Vector2) -> Vector2:
	var max_x := viewport_size.x - panel_size.x - VIEWPORT_MARGIN
	var max_y := viewport_size.y - panel_size.y - VIEWPORT_MARGIN
	return Vector2(
		VIEWPORT_MARGIN if max_x < VIEWPORT_MARGIN else clamp(position.x, VIEWPORT_MARGIN, max_x),
		VIEWPORT_MARGIN if max_y < VIEWPORT_MARGIN else clamp(position.y, VIEWPORT_MARGIN, max_y)
	)

func _free_panels() -> void:
	if main_panel != null and is_instance_valid(main_panel):
		main_panel.queue_free()
	main_panel = null

	for panel in keyword_panels:
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
	keyword_panels.clear()

func _cancel_pending_hover() -> void:
	pending_source = null
	hover_delay_timer = null
	hover_request_id += 1

func _on_hover_delay_elapsed(request_id: int) -> void:
	if request_id != hover_request_id:
		return
	var source: Object = pending_source
	if source == null:
		return
	if not is_instance_valid(source):
		clear()
		return

	pending_source = null
	hover_delay_timer = null
	_show_for_source_now(source)

func _on_source_mouse_entered(source: Control) -> void:
	show_for_source_delayed(source)

func _on_source_mouse_exited(source: Control) -> void:
	if source == active_source or source == pending_source:
		clear()

func _refresh_if_formula_modifier_changed() -> void:
	var formula_modifier_pressed := _is_formula_modifier_pressed()
	if formula_modifier_pressed == last_formula_modifier_pressed:
		return

	last_formula_modifier_pressed = formula_modifier_pressed
	if active_source != null and is_instance_valid(active_source):
		_show_for_source_now(active_source)

func _is_formula_modifier_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)
