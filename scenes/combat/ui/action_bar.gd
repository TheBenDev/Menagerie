## Hotbar control that binds scene buttons to configurable slot contents.
class_name BattleActionBar
extends Control

const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const HotbarSlotSchemaScript := preload("res://core/combat/classes/hotbar_slot_schema.gd")

const HOVER_INFO_META := &"hover_info_data"

@export var hotkey_bindings: Array[Dictionary] = [
	{"slot_id": &"strike", "hotkey_label": "1", "keycode": KEY_1},
	{"slot_id": &"guard", "hotkey_label": "2", "keycode": KEY_2},
	{"slot_id": &"ability_1", "hotkey_label": "3", "keycode": KEY_3},
	{"slot_id": &"ability_2", "hotkey_label": "4", "keycode": KEY_4},
	{"slot_id": &"ability_3", "hotkey_label": "5", "keycode": KEY_5},
	{"slot_id": &"ability_4", "hotkey_label": "6", "keycode": KEY_6},
	{"slot_id": &"ability_5", "hotkey_label": "7", "keycode": KEY_7},
	{"slot_id": &"ability_6", "hotkey_label": "8", "keycode": KEY_8},
	{"slot_id": &"consumable_1", "hotkey_label": "9", "keycode": KEY_9},
	{"slot_id": &"consumable_2", "hotkey_label": "0", "keycode": KEY_0},
	{"slot_id": &"consumable_3", "hotkey_label": "-", "keycode": KEY_MINUS},
	{"slot_id": &"consumable_4", "hotkey_label": "=", "keycode": KEY_EQUAL},
]

signal slot_selected(slot_id: StringName)
signal slot_hovered(source: Control)
signal slot_hover_ended()

var actions: Array[CombatActionData] = []
var buttons: Array[Button] = []
var slot_ids: Array[StringName] = []
var hotkey_slot_ids: Array[StringName] = []
var hotkey_label_by_slot_id: Dictionary = {}
var hotkey_slot_id_by_keycode: Dictionary = {}
var slot_entries: Dictionary = {}
var can_choose: bool = false
var hover_actor: Combatant = null

func _ready() -> void:
	_collect_buttons()
	_refresh_hotkey_bindings()
	_assign_default_action_slots()
	_update_buttons()

func set_actions(new_actions: Array[CombatActionData]) -> void:
	actions = new_actions.duplicate()
	_assign_default_action_slots()
	_update_buttons()

func set_hover_actor(new_hover_actor: Combatant) -> void:
	hover_actor = new_hover_actor
	_update_buttons()

func set_hotbar_slots(new_slot_entries: Array[Dictionary]) -> void:
	slot_entries.clear()
	for entry in new_slot_entries:
		var slot_id: StringName = _slot_id_from_entry(entry)
		if slot_id == &"":
			continue

		slot_entries[slot_id] = _normalized_slot_entry(slot_id, entry)

	_update_buttons()

func set_hotkey_bindings(new_hotkey_bindings: Array[Dictionary]) -> void:
	hotkey_bindings = new_hotkey_bindings.duplicate(true)
	_refresh_hotkey_bindings()
	_update_buttons()

func set_slot_entry(slot_id: StringName, entry: Dictionary) -> void:
	if slot_id == &"":
		return

	slot_entries[slot_id] = _normalized_slot_entry(slot_id, entry)
	_update_buttons()

func clear_slot(slot_id: StringName) -> void:
	if slot_id == &"":
		return

	slot_entries.erase(slot_id)
	_update_buttons()

func get_slot_entry(slot_id: StringName) -> Dictionary:
	var entry_value: Variant = slot_entries.get(slot_id, {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		return entry.duplicate()

	return {}

func set_can_choose(new_can_choose: bool) -> void:
	can_choose = new_can_choose
	_update_buttons()

func choose_slot_id(slot_id: StringName) -> void:
	if not can_choose:
		return

	var entry: Dictionary = _slot_entry_for_id(slot_id)
	if not _slot_selectable(entry):
		return

	slot_selected.emit(slot_id)

func choose_slot_index(index: int) -> void:
	if index < 0 or index >= hotkey_slot_ids.size():
		return

	choose_slot_id(hotkey_slot_ids[index])

func choose_hotkey_keycode(keycode: int) -> void:
	var slot_id: StringName = _hotkey_slot_id_for_keycode(keycode)
	if slot_id == &"":
		return

	choose_slot_id(slot_id)

func _collect_buttons() -> void:
	buttons.clear()
	slot_ids.clear()
	for child in get_children():
		if child is Button:
			var button: Button = child as Button
			var slot_id: StringName = _button_slot_id(button)
			buttons.append(button)
			slot_ids.append(slot_id)
			_connect_button(button)

func _refresh_hotkey_bindings() -> void:
	hotkey_slot_ids.clear()
	hotkey_label_by_slot_id.clear()
	hotkey_slot_id_by_keycode.clear()

	for binding in hotkey_bindings:
		var slot_id: StringName = _slot_id_from_entry(binding)
		if slot_id == &"":
			continue

		var keycode: int = int(binding.get("keycode", 0))
		if keycode == 0:
			continue

		hotkey_slot_ids.append(slot_id)
		hotkey_label_by_slot_id[slot_id] = str(binding.get("hotkey_label", ""))
		hotkey_slot_id_by_keycode[keycode] = slot_id

func _connect_button(button: Button) -> void:
	if button.has_signal("slot_pressed"):
		var slot_pressed_callback: Callable = Callable(self, "_on_slot_button_pressed")
		if not button.is_connected("slot_pressed", slot_pressed_callback):
			button.connect("slot_pressed", slot_pressed_callback)

		var slot_hovered_callback: Callable = Callable(self, "_on_slot_button_hovered")
		if button.has_signal("slot_hovered") and not button.is_connected("slot_hovered", slot_hovered_callback):
			button.connect("slot_hovered", slot_hovered_callback)

		var slot_hover_ended_callback: Callable = Callable(self, "_on_slot_button_hover_ended")
		if button.has_signal("slot_hover_ended") and not button.is_connected("slot_hover_ended", slot_hover_ended_callback):
			button.connect("slot_hover_ended", slot_hover_ended_callback)
		return

	var slot_id: StringName = _button_slot_id(button)
	var pressed_callback: Callable = _on_plain_button_pressed.bind(slot_id)
	if not button.pressed.is_connected(pressed_callback):
		button.pressed.connect(pressed_callback)

	var hover_callback: Callable = _on_plain_button_mouse_entered.bind(slot_id, button)
	if not button.mouse_entered.is_connected(hover_callback):
		button.mouse_entered.connect(hover_callback)

	if not button.mouse_exited.is_connected(_on_plain_button_mouse_exited):
		button.mouse_exited.connect(_on_plain_button_mouse_exited)

func _assign_default_action_slots() -> void:
	slot_entries.clear()
	var action_by_id: Dictionary = _action_by_id()
	for button in buttons:
		var slot_id: StringName = _button_slot_id(button)
		var default_action_id: String = _button_default_action_id(button)
		if default_action_id.is_empty():
			slot_entries[slot_id] = _empty_slot_entry(slot_id, button)
			continue

		var action := action_by_id.get(default_action_id, null) as CombatActionData
		if action == null:
			slot_entries[slot_id] = _empty_slot_entry(slot_id, button)
			continue

		slot_entries[slot_id] = _action_slot_entry(slot_id, action)

func _action_by_id() -> Dictionary:
	var action_by_id: Dictionary = {}
	for action in actions:
		if action == null or action.id.is_empty():
			continue

		action_by_id[action.id] = action

	return action_by_id

func _update_buttons() -> void:
	for button in buttons:
		var slot_id: StringName = _button_slot_id(button)
		var entry: Dictionary = _slot_entry_for_id(slot_id)
		if entry.is_empty():
			entry = _empty_slot_entry(slot_id, button)

		var has_content: bool = _slot_has_content(entry)
		var selectable: bool = can_choose and _slot_selectable(entry)
		button.visible = true
		button.disabled = not selectable
		button.tooltip_text = ""
		button.text = _button_label_for_slot(button, entry)
		_apply_button_hotkey_label(button, slot_id)

		if has_content:
			_set_slot_hover_info(button, entry)
		else:
			_clear_hover_info(button)

func _slot_entry_for_id(slot_id: StringName) -> Dictionary:
	var entry_value: Variant = slot_entries.get(slot_id, {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		return entry

	return {}

func _normalized_slot_entry(slot_id: StringName, entry: Dictionary) -> Dictionary:
	var normalized_entry: Dictionary = entry.duplicate()
	normalized_entry["slot_id"] = slot_id
	if not normalized_entry.has("kind"):
		if normalized_entry.has("action") or normalized_entry.has("action_id"):
			normalized_entry["kind"] = &"action"
		else:
			normalized_entry["kind"] = &"empty"

	if _slot_kind(normalized_entry) == &"action":
		var action: CombatActionData = _action_from_entry(normalized_entry)
		if action != null:
			normalized_entry["action"] = action
			normalized_entry["action_id"] = action.id
			if str(normalized_entry.get("label", "")).is_empty():
				normalized_entry["label"] = _button_label_for_action(action)
			if str(normalized_entry.get("display_name", "")).is_empty():
				normalized_entry["display_name"] = action.display_name
			if str(normalized_entry.get("description", "")).is_empty():
				normalized_entry["description"] = _description_for_action(action)

	return normalized_entry

func _empty_slot_entry(slot_id: StringName, button: Button) -> Dictionary:
	return {
		"slot_id": slot_id,
		"kind": &"empty",
		"label": _button_empty_label(button),
	}

func _action_slot_entry(slot_id: StringName, action: CombatActionData) -> Dictionary:
	return {
		"slot_id": slot_id,
		"kind": &"action",
		"action": action,
		"action_id": action.id,
		"label": _button_label_for_action(action),
		"display_name": action.display_name,
		"description": _description_for_action(action),
	}

func _slot_has_content(entry: Dictionary) -> bool:
	return _slot_kind(entry) != &"empty"

func _slot_selectable(entry: Dictionary) -> bool:
	return HotbarSlotSchemaScript.is_selectable(entry)

func _slot_kind(entry: Dictionary) -> StringName:
	return HotbarSlotSchemaScript.slot_kind(entry)

func _slot_id_from_entry(entry: Dictionary) -> StringName:
	return HotbarSlotSchemaScript.slot_id(entry)

func _button_slot_id(button: Button) -> StringName:
	if button.has_method("get_resolved_slot_id"):
		var resolved_slot_id: Variant = button.call("get_resolved_slot_id")
		return _string_name_value(resolved_slot_id)

	var metadata_value: Variant = button.get_meta("slot_id", &"")
	if metadata_value is StringName:
		return metadata_value
	if not str(metadata_value).is_empty():
		return StringName(str(metadata_value))

	return StringName(button.name)

func _button_default_action_id(button: Button) -> String:
	var exported_value: Variant = button.get("default_action_id")
	if exported_value != null:
		return str(exported_value)

	var metadata_value: Variant = button.get_meta("default_action_id", "")
	return str(metadata_value)

func _button_empty_label(button: Button) -> String:
	var exported_value: Variant = button.get("empty_label")
	if exported_value != null:
		return str(exported_value)

	return button.text

func _string_name_value(value: Variant) -> StringName:
	return ValueReaderScript.string_name_from_variant(value)

func _hotkey_slot_id_for_keycode(keycode: int) -> StringName:
	var slot_id_value: Variant = hotkey_slot_id_by_keycode.get(keycode, &"")
	return _string_name_value(slot_id_value)

func _apply_button_hotkey_label(button: Button, slot_id: StringName) -> void:
	if not button.has_method("set_hotkey_label"):
		return

	var hotkey_label: String = str(hotkey_label_by_slot_id.get(slot_id, ""))
	button.call("set_hotkey_label", hotkey_label)

func _button_label_for_slot(button: Button, entry: Dictionary) -> String:
	var label: String = str(entry.get("label", ""))
	if not label.is_empty():
		return label

	if _slot_kind(entry) == &"action":
		var action: CombatActionData = _action_from_entry(entry)
		if action != null:
			return _button_label_for_action(action)

	return _button_empty_label(button)

func _button_label_for_action(action: CombatActionData) -> String:
	var action_id: String = action.id.to_lower()
	var action_name: String = action.display_name.to_lower()
	if action_id.contains("guard") or action_name.contains("guard"):
		return "G"
	if action_id.contains("heavy") or action_name.contains("heavy"):
		return "H"
	if action_id.contains("strike") or action_name.contains("strike"):
		return "S"
	if not action.display_name.is_empty():
		return action.display_name.substr(0, 1).to_upper()

	return "?"

func _action_from_entry(entry: Dictionary) -> CombatActionData:
	var action_value: Variant = entry.get("action", null)
	if action_value is CombatActionData:
		return action_value

	var action_id: String = str(entry.get("action_id", ""))
	if action_id.is_empty():
		return null

	for action in actions:
		if action != null and action.id == action_id:
			return action

	return null

func _description_for_action(action: CombatActionData) -> String:
	var description: String = action.description.strip_edges()
	if description.is_empty() and action is PlayerActionData:
		var player_action: PlayerActionData = action as PlayerActionData
		description = player_action.tooltip_text.strip_edges()

	return description

func _set_slot_hover_info(button: Button, entry: Dictionary) -> void:
	if button.has_method("set_hover_info_provider"):
		button.call("set_hover_info_provider", _hover_info_for_entry.bind(entry))
		return

	_set_button_hover_info(button, _hover_info_for_entry(entry))

func _hover_info_for_entry(entry: Dictionary) -> Resource:
	if _slot_kind(entry) == &"action":
		var action: CombatActionData = _action_from_entry(entry)
		if action != null:
			return action.get_hover_info(hover_actor, _is_formula_modifier_pressed())

	var hover_info_value: Variant = entry.get("hover_info", null)
	if hover_info_value is Resource:
		return hover_info_value

	var resource_value := entry.get("resource", null) as Resource
	if resource_value != null and resource_value.has_method("get_hover_info"):
		var resource_info := resource_value.call("get_hover_info") as Resource
		if resource_info != null:
			return resource_info

	var info = load("res://core/hover_info/hover_info_data.gd").new()
	var display_name: String = str(entry.get("display_name", ""))
	var description: String = str(entry.get("description", ""))
	info.title = display_name
	info.description = description
	info.footer = str(entry.get("footer", "")).strip_edges()
	info.keyword_ids.append_array(_keyword_ids_from_variant(entry.get("keyword_ids", [])))
	info.panel_style = StringName(str(_slot_kind(entry)))

	var details_value: Variant = entry.get("details", [])
	if details_value is Array:
		for raw_detail in details_value:
			info.add_field("", str(raw_detail))
	elif details_value is PackedStringArray:
		for detail in details_value:
			info.add_field("", str(detail))

	return info

func _keyword_ids_from_variant(value: Variant) -> Array[StringName]:
	return ValueReaderScript.string_name_array(value)

func _set_button_hover_info(button: Button, info: Resource) -> void:
	if button.has_method("set_hover_info"):
		button.call("set_hover_info", info)
		return

	button.set_meta(HOVER_INFO_META, info)

func _clear_hover_info(button: Button) -> void:
	if button.has_method("set_hover_info_provider"):
		button.call("set_hover_info_provider", Callable())
	if button.has_method("set_hover_info"):
		button.call("set_hover_info", null)
	if button.has_meta(HOVER_INFO_META):
		button.remove_meta(HOVER_INFO_META)

func _is_formula_modifier_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

func _on_slot_button_pressed(slot_id: StringName) -> void:
	choose_slot_id(slot_id)

func _on_slot_button_hovered(slot_id: StringName, source: Control) -> void:
	if _slot_has_content(_slot_entry_for_id(slot_id)):
		slot_hovered.emit(source)

func _on_slot_button_hover_ended(_slot_id: StringName, _source: Control) -> void:
	slot_hover_ended.emit()

func _on_plain_button_pressed(slot_id: StringName) -> void:
	choose_slot_id(slot_id)

func _on_plain_button_mouse_entered(slot_id: StringName, source: Control) -> void:
	if _slot_has_content(_slot_entry_for_id(slot_id)):
		slot_hovered.emit(source)

func _on_plain_button_mouse_exited() -> void:
	slot_hover_ended.emit()
