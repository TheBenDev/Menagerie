## Horizontal action bar that displays available player actions and emits selected action indexes.
class_name BattleActionBar
extends HBoxContainer

signal action_selected(index: int)

var actions: Array[CombatActionData] = []
var buttons: Array[Button] = []
var can_choose: bool = false

func _ready() -> void:
	_collect_buttons()

func set_actions(new_actions: Array[CombatActionData]) -> void:
	actions = new_actions.duplicate()
	_ensure_button_count(actions.size())
	_update_buttons()

func set_can_choose(new_can_choose: bool) -> void:
	can_choose = new_can_choose
	_update_buttons()

func choose_action_index(index: int) -> void:
	if not can_choose or index < 0 or index >= actions.size():
		return

	action_selected.emit(index)

func _collect_buttons() -> void:
	buttons.clear()
	for child in get_children():
		if child is Button:
			var button := child as Button
			buttons.append(button)

	for index in buttons.size():
		_connect_button(buttons[index], index)

func _ensure_button_count(count: int) -> void:
	while buttons.size() < count:
		var button := Button.new()
		button.name = "ActionButton%s" % buttons.size()
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(button)
		buttons.append(button)
		_connect_button(button, buttons.size() - 1)

func _connect_button(button: Button, index: int) -> void:
	var callback := _on_button_pressed.bind(index)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _update_buttons() -> void:
	for index in buttons.size():
		var button := buttons[index]
		if index < actions.size():
			var action: CombatActionData = actions[index]
			button.text = "%s (%ss)" % [action.display_name, CombatTime.format_seconds(action.time_cost)]
			button.visible = true
			button.disabled = not can_choose
		else:
			button.visible = false
			button.disabled = true

func _on_button_pressed(index: int) -> void:
	choose_action_index(index)
