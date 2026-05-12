## Reusable battle display for one combatant's visual, resources, and statuses.
class_name CombatantDisplay
extends Control

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")
const ResourceBarScript := preload("res://scenes/ui/common/resource_bar.gd")
const StatusIconViewScene := preload("res://scenes/combat/ui/StatusIconView.tscn")

@export var status_icon_size: Vector2 = Vector2(32.0, 32.0)
@export var name_label_gap: float = 6.0

@onready var visual_frame: Control = $DisplayColumn/VisualFrame
@onready var name_label: Label = $DisplayColumn/VisualFrame/NameLabel
@onready var visual_root: Control = $DisplayColumn/VisualFrame/VisualRoot
@onready var visual_placeholder: ColorRect = $DisplayColumn/VisualFrame/VisualRoot/VisualPlaceholder
@onready var health_resource_row: Control = $DisplayColumn/HealthResourceRow
@onready var health_bar: ResourceBarScript = $DisplayColumn/HealthResourceRow/HealthBar
@onready var block_bar: ResourceBarScript = $DisplayColumn/HealthResourceRow/BlockBar
@onready var class_resource_row: Control = $DisplayColumn/ClassResourceRow
@onready var class_resource_bar: ResourceBarScript = $DisplayColumn/ClassResourceRow/ClassResourceBar
@onready var health_label: Label = $DisplayColumn/HealthResourceRow/HealthLabel
@onready var block_label: Label = $DisplayColumn/HealthResourceRow/BlockLabel
@onready var class_resource_label: Label = $DisplayColumn/ClassResourceRow/ClassResourceLabel
@onready var status_bar: Control = $DisplayColumn/StatusBar
@onready var status_icons: Control = $DisplayColumn/StatusBar/StatusIcons

var combatant: Combatant = null
var visual_instance: Node = null
var health_bar_config: Resource = null
var class_resource_config: Resource = null
var status_buttons: Array[Control] = []

func _ready() -> void:
	visual_frame.resized.connect(_queue_name_label_position_update)
	visual_root.resized.connect(_queue_name_label_position_update)
	NumberFontHelper.apply_to_label(health_label)
	NumberFontHelper.apply_to_label(block_label)
	NumberFontHelper.apply_to_label(class_resource_label)
	_configure_empty_state()

func setup(new_combatant: Combatant) -> void:
	combatant = new_combatant
	_connect_combatant_signals()
	_apply_profile()
	refresh()

func refresh(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	if combatant == null:
		_configure_empty_state()
		return

	name_label.text = combatant.display_name
	_queue_name_label_position_update()
	_update_health_and_block_bars()
	_update_class_resource_bar()
	_update_status_bar()

func _configure_empty_state() -> void:
	name_label.text = ""
	visual_placeholder.visible = true
	_queue_name_label_position_update()
	health_resource_row.visible = false
	health_bar.visible = false
	block_bar.visible = false
	class_resource_row.visible = false
	class_resource_bar.visible = false
	health_label.visible = false
	block_label.visible = false
	class_resource_label.visible = false
	status_bar.visible = true

func _connect_combatant_signals() -> void:
	if combatant == null:
		return

	if not combatant.hp_changed.is_connected(refresh):
		combatant.hp_changed.connect(refresh)
	if not combatant.block_changed.is_connected(refresh):
		combatant.block_changed.connect(refresh)
	if not combatant.statuses_changed.is_connected(refresh):
		combatant.statuses_changed.connect(refresh)
	if not combatant.action_started.is_connected(refresh):
		combatant.action_started.connect(refresh)
	if not combatant.action_resolved.is_connected(refresh):
		combatant.action_resolved.connect(refresh)
	if not combatant.died.is_connected(refresh):
		combatant.died.connect(refresh)
	if combatant.has_signal("rage_changed") and not combatant.is_connected("rage_changed", Callable(self, "refresh")):
		combatant.connect("rage_changed", Callable(self, "refresh"))

func _apply_profile() -> void:
	if combatant == null:
		return

	health_bar_config = combatant.get_health_bar_config()
	class_resource_config = _first_class_resource_config()
	name_label.text = combatant.display_name
	visual_placeholder.color = combatant.get_placeholder_color()
	_apply_visual_scene()
	_configure_health_bar()
	_configure_block_bar()
	_configure_class_resource_bar()

func _apply_visual_scene() -> void:
	_clear_visual_instance()
	var visual_scene: PackedScene = combatant.get_battle_visual_scene()
	if visual_scene == null:
		visual_placeholder.visible = true
		return

	visual_instance = visual_scene.instantiate()
	visual_root.add_child(visual_instance)
	visual_placeholder.visible = false
	if visual_instance is Control:
		var visual_control: Control = visual_instance as Control
		visual_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		visual_control.offset_left = 0.0
		visual_control.offset_top = 0.0
		visual_control.offset_right = 0.0
		visual_control.offset_bottom = 0.0
		visual_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not visual_control.resized.is_connected(_queue_name_label_position_update):
			visual_control.resized.connect(_queue_name_label_position_update)
	if visual_instance.has_signal("visual_bounds_changed") and not visual_instance.is_connected(
		"visual_bounds_changed",
		Callable(self, "_on_visual_bounds_changed")
	):
		visual_instance.connect("visual_bounds_changed", Callable(self, "_on_visual_bounds_changed"))
	_queue_name_label_position_update()

func _clear_visual_instance() -> void:
	if visual_instance != null and is_instance_valid(visual_instance):
		visual_instance.queue_free()
	visual_instance = null
	_queue_name_label_position_update()

func _on_visual_bounds_changed(_bounds: Rect2) -> void:
	_queue_name_label_position_update()

func _queue_name_label_position_update() -> void:
	call_deferred("_update_name_label_position")

func _update_name_label_position() -> void:
	if name_label == null or visual_frame == null:
		return

	var label_height: float = maxf(name_label.custom_minimum_size.y, name_label.get_combined_minimum_size().y)
	var label_width: float = maxf(visual_frame.size.x, 1.0)
	var label_y: float = 0.0
	var bounds := _visual_bounds_in_frame()
	if bounds.size.y > 0.0:
		label_y = bounds.position.y - name_label_gap - label_height

	label_y = clampf(label_y, 0.0, maxf(visual_frame.size.y - label_height, 0.0))
	name_label.position = Vector2(0.0, label_y)
	name_label.size = Vector2(label_width, label_height)

func _visual_bounds_in_frame() -> Rect2:
	if visual_instance != null and is_instance_valid(visual_instance) and visual_instance.has_method("get_visual_bounds"):
		var bounds: Rect2 = visual_instance.call("get_visual_bounds")
		if bounds.size.y > 0.0:
			var visual_origin := visual_root.position
			if visual_instance is Control:
				visual_origin += (visual_instance as Control).position
			return Rect2(visual_origin + bounds.position, bounds.size)

	if visual_placeholder.visible:
		return Rect2(visual_root.position, visual_root.size)

	return Rect2()

func _configure_health_bar() -> void:
	health_resource_row.visible = true
	health_bar.visible = true
	if health_bar_config != null:
		health_bar.configure_from_config(health_bar_config)
	else:
		health_bar.resource_name = "HP"
		health_bar.display_reference_value = true
	health_bar.bonus_label = ""
	health_bar.fill_start_value = 0
	health_bar.draw_text = false
	health_label.visible = true

func _configure_block_bar() -> void:
	block_bar.resource_name = ""
	block_bar.display_reference_value = false
	block_bar.low_color = Color(0.2, 0.55, 1.0, 0.72)
	block_bar.high_color = Color(0.2, 0.55, 1.0, 0.72)
	block_bar.over_reference_color = Color(0.4, 0.75, 1.0, 0.82)
	block_bar.background_color = Color.TRANSPARENT
	block_bar.border_color = Color.TRANSPARENT
	block_bar.text_color = Color.TRANSPARENT
	block_bar.bonus_label = ""
	block_bar.fill_start_value = 0
	block_bar.draw_text = false

func _configure_class_resource_bar() -> void:
	class_resource_row.visible = class_resource_config != null
	class_resource_bar.visible = class_resource_config != null
	class_resource_label.visible = class_resource_config != null
	if class_resource_config == null:
		return

	class_resource_bar.configure_from_config(class_resource_config)
	class_resource_bar.fill_start_value = 0
	class_resource_bar.draw_text = false

func _first_class_resource_config() -> Resource:
	var configs: Array[Resource] = combatant.get_resource_bar_configs()
	if configs.is_empty():
		return null

	return configs[0]

func _update_health_and_block_bars() -> void:
	var max_hp: int = max(combatant.max_hp, 1)
	health_bar.set_values(combatant.hp, max_hp, 0)
	block_bar.set_segment_values(0, combatant.block, max_hp)
	block_bar.visible = combatant.block > 0
	block_label.visible = combatant.block > 0
	health_label.text = "HP %s/%s" % [combatant.hp, max_hp]
	block_label.text = "Block %s" % combatant.block

func _update_class_resource_bar() -> void:
	class_resource_row.visible = class_resource_config != null
	class_resource_bar.visible = class_resource_config != null
	class_resource_label.visible = class_resource_config != null
	if class_resource_config == null:
		return

	var resource_id: String = str(class_resource_config.get("resource_id"))
	var snapshot: Dictionary = combatant.get_resource_snapshot(resource_id)
	var current_value: int = int(snapshot.get("current", 0))
	var reference_value: int = int(snapshot.get("reference", int(class_resource_config.get("reference_value"))))
	class_resource_bar.set_values(current_value, reference_value, int(snapshot.get("bonus", 0)))
	class_resource_label.text = _class_resource_text(current_value, reference_value)

func _class_resource_text(current_value: int, reference_value: int) -> String:
	var label: String = str(class_resource_config.get("label"))
	if bool(class_resource_config.get("display_reference_value")):
		return "%s %s/%s" % [label, current_value, reference_value]

	return "%s %s" % [label, current_value]

func _update_status_bar() -> void:
	var status_entries: Array[Dictionary] = _active_status_entries()
	status_bar.visible = true
	_ensure_status_button_count(status_entries.size())

	for index in status_buttons.size():
		var button: Control = status_buttons[index]
		if index < status_entries.size():
			button.call("set_status_entry", status_entries[index])
			button.visible = true
			button.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			button.visible = false
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.call("clear_status_entry")

func _active_status_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_status_id: Variant in combatant.statuses.keys():
		var status_id: String = str(raw_status_id)
		if not combatant.has_status(status_id):
			continue

		var state: Dictionary = combatant.statuses[status_id]
		var status_data: Resource = state.get("data", null) as Resource
		var display_name: String = status_id.capitalize()
		if status_data != null:
			var display_name_value: Variant = status_data.get("display_name")
			if not str(display_name_value).is_empty():
				display_name = str(display_name_value)

		entries.append({
			"id": status_id,
			"display_name": display_name,
			"remaining_seconds": combatant.get_status_remaining(status_id),
			"data": status_data,
		})

	entries.sort_custom(_sort_status_entries)
	return entries

func _ensure_status_button_count(count: int) -> void:
	while status_buttons.size() < count:
		var button: Control = StatusIconViewScene.instantiate() as Control
		button.name = "StatusIcon%s" % status_buttons.size()
		button.custom_minimum_size = status_icon_size
		status_icons.add_child(button)
		status_buttons.append(button)

func _sort_status_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_name: String = str(a.get("display_name", ""))
	var b_name: String = str(b.get("display_name", ""))
	return a_name.naturalnocasecmp_to(b_name) < 0
