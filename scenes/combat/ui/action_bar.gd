## Hotbar control that binds scene buttons to configurable slot contents.
class_name BattleActionBar
extends Control

const HoverInfoPanelScript := preload("res://scenes/combat/ui/hover_info_panel.gd")

const SLOT_KIND_EMPTY: StringName = &"empty"
const SLOT_KIND_ACTION: StringName = &"action"
const SLOT_KIND_CONSUMABLE: StringName = &"consumable"

const SLOT_ID_KEY: String = "slot_id"
const KIND_KEY: String = "kind"
const ACTION_KEY: String = "action"
const ACTION_ID_KEY: String = "action_id"
const ACTION_INDEX_KEY: String = "action_index"
const LABEL_KEY: String = "label"
const DISPLAY_NAME_KEY: String = "display_name"
const DESCRIPTION_KEY: String = "description"
const DETAILS_KEY: String = "details"
const HOTKEY_KEYCODE_KEY: String = "keycode"
const HOTKEY_LABEL_KEY: String = "hotkey_label"

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

func _ready() -> void:
	_collect_buttons()
	_refresh_hotkey_bindings()
	_assign_default_action_slots()
	_update_buttons()

func set_actions(new_actions: Array[CombatActionData]) -> void:
	actions = new_actions.duplicate()
	_assign_default_action_slots()
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
	if not _slot_has_content(entry):
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

func choose_action_index(index: int) -> void:
	for slot_id in slot_ids:
		var entry: Dictionary = _slot_entry_for_id(slot_id)
		if int(entry.get(ACTION_INDEX_KEY, -1)) == index:
			choose_slot_id(slot_id)
			return

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

		var keycode: int = int(binding.get(HOTKEY_KEYCODE_KEY, 0))
		if keycode == 0:
			continue

		hotkey_slot_ids.append(slot_id)
		hotkey_label_by_slot_id[slot_id] = str(binding.get(HOTKEY_LABEL_KEY, ""))
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
	var action_index_by_id: Dictionary = _action_index_by_id()
	for button in buttons:
		var slot_id: StringName = _button_slot_id(button)
		var default_action_id: String = _button_default_action_id(button)
		if default_action_id.is_empty():
			slot_entries[slot_id] = _empty_slot_entry(slot_id, button)
			continue

		var action_index: int = int(action_index_by_id.get(default_action_id, -1))
		if action_index < 0 or action_index >= actions.size():
			slot_entries[slot_id] = _empty_slot_entry(slot_id, button)
			continue

		slot_entries[slot_id] = _action_slot_entry(slot_id, action_index, actions[action_index])

func _action_index_by_id() -> Dictionary:
	var index_by_id: Dictionary = {}
	for index in actions.size():
		var action: CombatActionData = actions[index]
		if action == null or action.id.is_empty():
			continue

		index_by_id[action.id] = index

	return index_by_id

func _update_buttons() -> void:
	for button in buttons:
		var slot_id: StringName = _button_slot_id(button)
		var entry: Dictionary = _slot_entry_for_id(slot_id)
		if entry.is_empty():
			entry = _empty_slot_entry(slot_id, button)

		var has_content: bool = _slot_has_content(entry)
		button.visible = true
		button.disabled = not can_choose or not has_content
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
	normalized_entry[SLOT_ID_KEY] = slot_id
	if not normalized_entry.has(KIND_KEY):
		if normalized_entry.has(ACTION_KEY) or normalized_entry.has(ACTION_ID_KEY) or normalized_entry.has(ACTION_INDEX_KEY):
			normalized_entry[KIND_KEY] = SLOT_KIND_ACTION
		else:
			normalized_entry[KIND_KEY] = SLOT_KIND_EMPTY

	if _slot_kind(normalized_entry) == SLOT_KIND_ACTION:
		var action: CombatActionData = _action_from_entry(normalized_entry)
		if action != null:
			var action_index: int = actions.find(action)
			normalized_entry[ACTION_KEY] = action
			normalized_entry[ACTION_ID_KEY] = action.id
			normalized_entry[ACTION_INDEX_KEY] = action_index
			if str(normalized_entry.get(LABEL_KEY, "")).is_empty():
				normalized_entry[LABEL_KEY] = _button_label_for_action(action)
			if str(normalized_entry.get(DISPLAY_NAME_KEY, "")).is_empty():
				normalized_entry[DISPLAY_NAME_KEY] = action.display_name
			if str(normalized_entry.get(DESCRIPTION_KEY, "")).is_empty():
				normalized_entry[DESCRIPTION_KEY] = _description_for_action(action)

	return normalized_entry

func _empty_slot_entry(slot_id: StringName, button: Button) -> Dictionary:
	return {
		SLOT_ID_KEY: slot_id,
		KIND_KEY: SLOT_KIND_EMPTY,
		LABEL_KEY: _button_empty_label(button),
	}

func _action_slot_entry(slot_id: StringName, action_index: int, action: CombatActionData) -> Dictionary:
	return {
		SLOT_ID_KEY: slot_id,
		KIND_KEY: SLOT_KIND_ACTION,
		ACTION_KEY: action,
		ACTION_ID_KEY: action.id,
		ACTION_INDEX_KEY: action_index,
		LABEL_KEY: _button_label_for_action(action),
		DISPLAY_NAME_KEY: action.display_name,
		DESCRIPTION_KEY: _description_for_action(action),
	}

func _slot_has_content(entry: Dictionary) -> bool:
	return _slot_kind(entry) != SLOT_KIND_EMPTY

func _slot_kind(entry: Dictionary) -> StringName:
	var kind_value: Variant = entry.get(KIND_KEY, SLOT_KIND_EMPTY)
	if kind_value is StringName:
		return kind_value

	return StringName(str(kind_value))

func _slot_id_from_entry(entry: Dictionary) -> StringName:
	var slot_id_value: Variant = entry.get(SLOT_ID_KEY, &"")
	if slot_id_value is StringName:
		return slot_id_value

	return StringName(str(slot_id_value))

func _button_slot_id(button: Button) -> StringName:
	if button.has_method("get_resolved_slot_id"):
		var resolved_slot_id: Variant = button.call("get_resolved_slot_id")
		return _string_name_value(resolved_slot_id)

	var metadata_value: Variant = button.get_meta(SLOT_ID_KEY, &"")
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
	if value is StringName:
		return value

	return StringName(str(value))

func _hotkey_slot_id_for_keycode(keycode: int) -> StringName:
	var slot_id_value: Variant = hotkey_slot_id_by_keycode.get(keycode, &"")
	return _string_name_value(slot_id_value)

func _apply_button_hotkey_label(button: Button, slot_id: StringName) -> void:
	if not button.has_method("set_hotkey_label"):
		return

	var hotkey_label: String = str(hotkey_label_by_slot_id.get(slot_id, ""))
	button.call("set_hotkey_label", hotkey_label)

func _button_label_for_slot(button: Button, entry: Dictionary) -> String:
	var label: String = str(entry.get(LABEL_KEY, ""))
	if not label.is_empty():
		return label

	if _slot_kind(entry) == SLOT_KIND_ACTION:
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
	var action_value: Variant = entry.get(ACTION_KEY, null)
	if action_value is CombatActionData:
		return action_value

	var action_index: int = int(entry.get(ACTION_INDEX_KEY, -1))
	if action_index >= 0 and action_index < actions.size():
		return actions[action_index]

	var action_id: String = str(entry.get(ACTION_ID_KEY, ""))
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
	if _slot_kind(entry) == SLOT_KIND_ACTION:
		var action: CombatActionData = _action_from_entry(entry)
		if action != null:
			_set_action_hover_info(button, action)
			return

	var display_name: String = str(entry.get(DISPLAY_NAME_KEY, ""))
	var description: String = str(entry.get(DESCRIPTION_KEY, ""))
	var details_value: Variant = entry.get(DETAILS_KEY, [])
	var details: Array[String] = []
	if details_value is Array:
		for raw_detail in details_value:
			details.append(str(raw_detail))

	button.set_meta(HoverInfoPanelScript.META_TITLE, display_name)
	button.set_meta(HoverInfoPanelScript.META_DESCRIPTION, description)
	button.set_meta(HoverInfoPanelScript.META_DETAILS, details)

func _set_action_hover_info(button: Button, action: CombatActionData) -> void:
	var details: Array[String] = ["Time: %ss" % CombatTime.format_seconds(action.time_cost)]
	if action.hp_cost > 0:
		details.append("HP Cost: %s" % action.hp_cost)
	if action.mana_cost > 0:
		details.append("Mana Cost: %s" % action.mana_cost)

	button.set_meta(HoverInfoPanelScript.META_TITLE, action.display_name)
	button.set_meta(HoverInfoPanelScript.META_DESCRIPTION, _description_for_action(action))
	button.set_meta(HoverInfoPanelScript.META_DETAILS, details)

func _clear_hover_info(button: Button) -> void:
	for meta_name in [
		HoverInfoPanelScript.META_TITLE,
		HoverInfoPanelScript.META_DESCRIPTION,
		HoverInfoPanelScript.META_DETAILS,
		HoverInfoPanelScript.META_TEXT,
	]:
		if button.has_meta(meta_name):
			button.remove_meta(meta_name)

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
