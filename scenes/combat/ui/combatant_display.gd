## Reusable battle display for one combatant's visual, resources, and statuses.
class_name CombatantDisplay
extends Control

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")
const ResourceBarScript := preload("res://scenes/ui/common/resource_bar.gd")
const StatusIconViewScene := preload("res://scenes/combat/ui/StatusIconView.tscn")

const TARGET_HIGHLIGHT_FILL := Color(1.0, 0.82, 0.24, 0.12)
const TARGET_HIGHLIGHT_BORDER := Color(1.0, 0.82, 0.24, 0.95)
const TARGET_HIGHLIGHT_BORDER_WIDTH := 4

signal target_selected(combatant: Combatant)

@export var status_icon_size: Vector2 = Vector2(32.0, 32.0)

@onready var visual_root: Control = $DisplayColumn/VisualFrame/VisualRoot
@onready var visual_placeholder: ColorRect = $DisplayColumn/VisualFrame/VisualRoot/VisualPlaceholder
@onready var health_resource_row: Control = $DisplayColumn/HealthResourceRow
@onready var health_bar: ResourceBarScript = $DisplayColumn/HealthResourceRow/HealthBar
@onready var block_bar: ResourceBarScript = $DisplayColumn/HealthResourceRow/BlockBar
@onready var health_label: Label = $DisplayColumn/HealthResourceRow/HealthLabel
@onready var block_label: Label = $DisplayColumn/HealthResourceRow/BlockLabel
@onready var name_panel: Control = $DisplayColumn/NamePanel
@onready var name_plate: Control = $DisplayColumn/NamePanel/NamePlate
@onready var name_label: Label = $DisplayColumn/NamePanel/NamePlate/NameLabel
@onready var status_bar: Control = $DisplayColumn/StatusBar
@onready var status_icons: Control = $DisplayColumn/StatusBar/StatusIcons

var combatant: Combatant = null
var visual_instance: Node = null
var health_bar_config: Resource = null
var status_buttons: Array[Control] = []
var is_hovering_display: bool = false
var can_select_as_target: bool = false
var is_target_highlighted: bool = false
var target_highlight_overlay: Panel = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_ensure_target_highlight_overlay()
	NumberFontHelper.apply_to_label(health_label)
	NumberFontHelper.apply_to_label(block_label)
	_configure_empty_state()

func setup(new_combatant: Combatant) -> void:
	combatant = new_combatant
	clear_targeting_state()
	_connect_combatant_signals()
	_apply_profile()
	refresh()

## Enables or clears this display as an explicit combat target candidate.
func set_targeting_state(can_select: bool, highlighted: bool = true) -> void:
	can_select_as_target = can_select and combatant != null and combatant.hp > 0
	is_target_highlighted = highlighted and can_select_as_target
	mouse_filter = Control.MOUSE_FILTER_STOP if can_select_as_target else Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_select_as_target else Control.CURSOR_ARROW
	_update_target_highlight()

## Clears any targeting highlight or click-selection state from this display.
func clear_targeting_state() -> void:
	can_select_as_target = false
	is_target_highlighted = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_update_target_highlight()

func refresh(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	if combatant == null:
		_configure_empty_state()
		return

	name_label.text = combatant.display_name
	name_panel.visible = true
	_sync_nameplate_visibility()
	_update_health_and_block_bars()
	_update_status_bar()

func _gui_input(event: InputEvent) -> void:
	if not can_select_as_target or combatant == null:
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			accept_event()
			target_selected.emit(combatant)

func _configure_empty_state() -> void:
	name_label.text = ""
	name_panel.visible = false
	name_plate.visible = true
	name_plate.modulate.a = 0.0
	visual_placeholder.visible = true
	health_resource_row.visible = false
	health_bar.visible = false
	block_bar.visible = false
	health_label.visible = false
	block_label.visible = false
	status_bar.visible = true

func _ensure_target_highlight_overlay() -> void:
	if target_highlight_overlay != null and is_instance_valid(target_highlight_overlay):
		return

	target_highlight_overlay = Panel.new()
	target_highlight_overlay.name = "TargetHighlight"
	target_highlight_overlay.visible = false
	target_highlight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_highlight_overlay.z_index = 100
	target_highlight_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	target_highlight_overlay.offset_left = 0.0
	target_highlight_overlay.offset_top = 0.0
	target_highlight_overlay.offset_right = 0.0
	target_highlight_overlay.offset_bottom = 0.0
	target_highlight_overlay.add_theme_stylebox_override("panel", _target_highlight_stylebox())
	add_child(target_highlight_overlay)

func _target_highlight_stylebox() -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = TARGET_HIGHLIGHT_FILL
	stylebox.border_color = TARGET_HIGHLIGHT_BORDER
	stylebox.set_border_width_all(TARGET_HIGHLIGHT_BORDER_WIDTH)
	stylebox.corner_detail = 2
	return stylebox

func _update_target_highlight() -> void:
	_ensure_target_highlight_overlay()
	target_highlight_overlay.visible = is_target_highlighted

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

func _apply_profile() -> void:
	if combatant == null:
		return

	health_bar_config = combatant.get_health_bar_config()
	name_label.text = combatant.display_name
	name_panel.visible = true
	_sync_nameplate_visibility()
	visual_placeholder.color = combatant.get_placeholder_color()
	_apply_visual_scene()
	_configure_health_bar()
	_configure_block_bar()

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

func _clear_visual_instance() -> void:
	if visual_instance != null and is_instance_valid(visual_instance):
		visual_instance.queue_free()
	visual_instance = null

func _sync_nameplate_visibility() -> void:
	name_plate.visible = combatant != null
	name_plate.modulate.a = 1.0 if is_hovering_display else 0.0

func _on_mouse_entered() -> void:
	is_hovering_display = true
	_sync_nameplate_visibility()

func _on_mouse_exited() -> void:
	is_hovering_display = false
	_sync_nameplate_visibility()

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

func _update_health_and_block_bars() -> void:
	var max_hp: int = max(combatant.max_hp, 1)
	health_bar.set_values(combatant.hp, max_hp, 0)
	block_bar.set_segment_values(0, combatant.block, max_hp)
	block_bar.visible = combatant.block > 0
	block_label.visible = combatant.block > 0
	health_label.text = "%s/%s" % [combatant.hp, max_hp]
	block_label.text = "%s" % combatant.block

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
