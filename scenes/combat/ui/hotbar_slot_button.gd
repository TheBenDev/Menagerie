## Button for one configurable combat hotbar slot.
class_name HotbarSlotButton
extends Button

signal slot_pressed(slot_id: StringName)
signal slot_hovered(slot_id: StringName, source: Control)
signal slot_hover_ended(slot_id: StringName, source: Control)

@export var slot_id: StringName = &""
@export var default_action_id: String = ""
@export var empty_label: String = ""

func _ready() -> void:
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

func _on_pressed() -> void:
	slot_pressed.emit(get_resolved_slot_id())

func _on_mouse_entered() -> void:
	slot_hovered.emit(get_resolved_slot_id(), self)

func _on_mouse_exited() -> void:
	slot_hover_ended.emit(get_resolved_slot_id(), self)
