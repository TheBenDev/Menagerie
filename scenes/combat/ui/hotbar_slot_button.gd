## Button for one configurable combat hotbar slot.
class_name HotbarSlotButton
extends Button

const HotkeyBadgeStylebox := preload("res://assets/ui/combat_hotbar_key_badge_stylebox.tres")

signal slot_pressed(slot_id: StringName)
signal slot_hovered(slot_id: StringName, source: Control)
signal slot_hover_ended(slot_id: StringName, source: Control)

@export var slot_id: StringName = &""
@export var default_action_id: String = ""
@export var empty_label: String = ""
@export var hotkey_label: String = ""

var hotkey_badge: PanelContainer = null
var hotkey_badge_label: Label = null

func _ready() -> void:
	_ensure_hotkey_badge()
	set_hotkey_label(hotkey_label)

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func get_resolved_slot_id() -> StringName:
	if slot_id != &"":
		return slot_id

	return StringName(name)

func set_hotkey_label(new_hotkey_label: String) -> void:
	hotkey_label = new_hotkey_label.strip_edges()
	_ensure_hotkey_badge()
	if hotkey_badge_label != null:
		hotkey_badge_label.text = hotkey_label
	if hotkey_badge != null:
		hotkey_badge.visible = not hotkey_label.is_empty()

func _ensure_hotkey_badge() -> void:
	if hotkey_badge != null and hotkey_badge_label != null:
		return

	var existing_badge := get_node_or_null("HotkeyBadge") as PanelContainer
	if existing_badge != null:
		hotkey_badge = existing_badge
		hotkey_badge_label = hotkey_badge.get_node_or_null("Label") as Label
		_apply_hotkey_badge_style()
		if hotkey_badge_label != null:
			return

	hotkey_badge = PanelContainer.new()
	hotkey_badge.name = "HotkeyBadge"
	hotkey_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotkey_badge.z_index = 20
	hotkey_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hotkey_badge.offset_left = 3.0
	hotkey_badge.offset_top = 3.0
	hotkey_badge.offset_right = 24.0
	hotkey_badge.offset_bottom = 21.0

	hotkey_badge_label = Label.new()
	hotkey_badge_label.name = "Label"
	hotkey_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotkey_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hotkey_badge_label.custom_minimum_size = Vector2(18.0, 14.0)
	_apply_hotkey_badge_style()
	hotkey_badge.add_child(hotkey_badge_label)
	add_child(hotkey_badge)

func _apply_hotkey_badge_style() -> void:
	if hotkey_badge != null:
		hotkey_badge.add_theme_stylebox_override("panel", HotkeyBadgeStylebox)
	if hotkey_badge_label != null:
		hotkey_badge_label.theme_type_variation = &"CombatHotbarKeyBadgeLabel"

func _on_pressed() -> void:
	slot_pressed.emit(get_resolved_slot_id())

func _on_mouse_entered() -> void:
	slot_hovered.emit(get_resolved_slot_id(), self)

func _on_mouse_exited() -> void:
	slot_hover_ended.emit(get_resolved_slot_id(), self)
