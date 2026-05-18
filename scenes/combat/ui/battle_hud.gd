## Battle screen HUD that coordinates the timeline, hotbar action buttons, player statuses, hover info, and time controls.
class_name BattleHUD
extends Control

const BattleActionBarScript := preload("res://scenes/combat/ui/action_bar.gd")
const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")
const ResourceBarScript := preload("res://scenes/ui/common/resource_bar.gd")
const StatusEntrySorterScript := preload("res://core/statuses/status_entry_sorter.gd")
const StatusIconViewScene := preload("res://scenes/combat/ui/StatusIconView.tscn")

@export var preview_status_atlas: bool = false
@export_range(1, 64) var preview_status_icon_count: int = 13
@export var preview_status_icon_cell_size: Vector2i = Vector2i(200, 200)
@export var memory_goal: int = 100

signal action_selected(index: int)
signal hotbar_slot_used(slot_id: StringName, slot_entry: Dictionary)
signal speed_requested()
signal pause_requested()

@onready var timeline_view: TimelineView = $TimelineRow/TimelinePanel/TimelineMargin/Timeline
@onready var speed_button: Button = $TimelineRow/TimeControls/SpeedButton
@onready var pause_button: Button = $TimelineRow/TimeControls/PauseButton
@onready var action_bar: BattleActionBarScript = $Hotbar/ActionBar
@onready var memory_bar: ResourceBarScript = $Hotbar/ResourceBars/MemoryBar
@onready var health_bar: ResourceBarScript = $Hotbar/ResourceBars/HealthBar
@onready var block_bar: ResourceBarScript = $Hotbar/ResourceBars/BlockBar
@onready var class_resource_bar: ResourceBarScript = $Hotbar/ResourceBars/ClassResourceBar
@onready var memory_label: Label = $Hotbar/ResourceLabels/MemoryLabel
@onready var health_label: Label = $Hotbar/ResourceLabels/HealthLabel
@onready var block_label: Label = $Hotbar/ResourceLabels/BlockLabel
@onready var class_resource_label: Label = $Hotbar/ResourceLabels/ClassResourceLabel
@onready var status_bar: Control = $StatusBar
@onready var status_icons: HBoxContainer = $StatusBar/StatusIcons
@onready var hover_info_panel: Node = $HoverInfoPanel

var battle: BattleController = null
var player: Combatant = null
var enemy: Combatant = null
var player_group: Variant = null
var enemy_group: Variant = null
var health_bar_config: Resource = null
var class_resource_config: Resource = null
var status_buttons: Array[Control] = []
var status_entries: Array[Dictionary] = []
var is_targeting_active: bool = false

func _ready() -> void:
	speed_button.pressed.connect(_on_speed_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	action_bar.slot_selected.connect(_on_hotbar_slot_selected)
	action_bar.slot_hovered.connect(_show_hover_info_for_source)
	action_bar.slot_hover_ended.connect(_clear_hover_info)
	NumberFontHelper.apply_to_button(speed_button)
	NumberFontHelper.apply_to_label(memory_label)
	NumberFontHelper.apply_to_label(health_label)
	NumberFontHelper.apply_to_label(block_label)
	NumberFontHelper.apply_to_label(class_resource_label)
	speed_button.tooltip_text = ""
	pause_button.tooltip_text = ""
	_configure_resource_bars()
	_connect_run_currency_signal()
	_configure_static_hover_sources()
	_clear_hover_info()

func setup(
	new_battle: BattleController,
	new_player: Combatant,
	new_enemy: Combatant,
	new_player_group: Variant = null,
	new_enemy_group: Variant = null
) -> void:
	battle = new_battle
	player = new_player
	enemy = new_enemy
	player_group = new_player_group
	enemy_group = new_enemy_group

	action_bar.set_actions(player.actions)
	_configure_resource_bars()
	refresh()

## Gates action-slot selection while the battle scene is waiting for target confirmation.
func set_targeting_active(new_is_targeting_active: bool) -> void:
	is_targeting_active = new_is_targeting_active
	refresh()

func refresh() -> void:
	if battle == null or player == null or enemy == null:
		return

	timeline_view.set_timeline_state(
		battle.current_time,
		_timeline_markers(),
		battle.is_advancing,
		battle.time_scale,
		battle.is_paused
	)

	speed_button.text = "%sx" % _format_speed(battle.time_scale)
	pause_button.text = ">" if battle.is_paused else "||"
	pause_button.disabled = battle.battle_over

	action_bar.set_can_choose(battle.waiting_for_player_input and not battle.battle_over and not is_targeting_active)
	_update_resource_bars()
	_update_status_bar()

func choose_action_index(index: int) -> void:
	action_bar.choose_action_index(index)

func choose_hotbar_slot_index(index: int) -> void:
	action_bar.choose_slot_index(index)

func choose_hotbar_keycode(keycode: int) -> void:
	action_bar.choose_hotkey_keycode(keycode)

func set_hotbar_keybindings(new_hotkey_bindings: Array[Dictionary]) -> void:
	action_bar.set_hotkey_bindings(new_hotkey_bindings)

func set_hotbar_slots(slot_entries: Array[Dictionary]) -> void:
	action_bar.set_hotbar_slots(slot_entries)

func set_hotbar_slot(slot_id: StringName, slot_entry: Dictionary) -> void:
	action_bar.set_slot_entry(slot_id, slot_entry)

func clear_hotbar_slot(slot_id: StringName) -> void:
	action_bar.clear_slot(slot_id)

func _configure_resource_bars() -> void:
	health_bar_config = player.get_health_bar_config() if player != null else null
	class_resource_config = _first_class_resource_config()

	_configure_memory_bar()
	_configure_health_bar()
	_configure_block_bar()
	_configure_class_resource_bar()

func _configure_memory_bar() -> void:
	if memory_bar == null:
		return

	memory_bar.resource_name = "Memories"
	memory_bar.display_reference_value = true
	memory_bar.low_color = Color(0.42, 0.32, 0.78, 1.0)
	memory_bar.high_color = Color(0.9, 0.72, 1.0, 1.0)
	memory_bar.over_reference_color = Color(1.0, 0.86, 0.38, 1.0)
	memory_bar.background_color = Color(0.04, 0.035, 0.07, 0.88)
	memory_bar.border_color = Color(0.62, 0.52, 0.9, 0.95)
	memory_bar.text_color = Color.WHITE
	memory_bar.bonus_label = ""
	memory_bar.fill_start_value = 0
	memory_bar.draw_text = false

func _configure_health_bar() -> void:
	if health_bar == null:
		return

	if health_bar_config != null:
		health_bar.configure_from_config(health_bar_config)
	else:
		health_bar.resource_name = "HP"
		health_bar.display_reference_value = true

	health_bar.bonus_label = ""
	health_bar.fill_start_value = 0
	health_bar.draw_text = false

func _configure_block_bar() -> void:
	if block_bar == null:
		return

	block_bar.resource_name = ""
	block_bar.display_reference_value = false
	block_bar.low_color = Color(0.2, 0.55, 1.0, 0.72)
	block_bar.high_color = Color(0.2, 0.55, 1.0, 0.72)
	block_bar.over_reference_color = Color(0.4, 0.75, 1.0, 0.82)
	block_bar.background_color = Color.TRANSPARENT
	block_bar.border_color = Color.TRANSPARENT
	block_bar.text_color = Color.TRANSPARENT
	block_bar.bonus_label = ""
	block_bar.draw_text = false

func _configure_class_resource_bar() -> void:
	if class_resource_bar == null:
		return

	class_resource_bar.visible = class_resource_config != null
	if class_resource_config == null:
		return

	class_resource_bar.configure_from_config(class_resource_config)
	class_resource_bar.fill_start_value = 0
	class_resource_bar.draw_text = false

func _first_class_resource_config() -> Resource:
	if player == null:
		return null

	var configs: Array[Resource] = player.get_resource_bar_configs()
	if configs.is_empty():
		return null

	return configs[0]

func _update_resource_bars() -> void:
	_update_memory_bar()
	_update_health_and_block_bars()
	_update_class_resource_bar()

func _update_memory_bar() -> void:
	if memory_bar == null:
		return

	var memories: int = _current_run_memories()
	var goal: int = max(memory_goal, 1)
	memory_bar.set_values(memories, goal, 0)
	if memory_label != null:
		memory_label.text = "%s/%s" % [memories, goal]

func _update_health_and_block_bars() -> void:
	if player == null or health_bar == null or block_bar == null:
		return

	var max_hp: int = max(player.max_hp, 1)
	health_bar.set_values(player.hp, max_hp, 0)
	block_bar.set_segment_values(0, player.block, max_hp)
	block_bar.visible = player.block > 0
	if health_label != null:
		health_label.text = "%s/%s" % [player.hp, max_hp]
	if block_label != null:
		block_label.visible = player.block > 0
		block_label.text = "%s" % player.block

func _update_class_resource_bar() -> void:
	if class_resource_bar == null:
		return

	class_resource_bar.visible = class_resource_config != null
	if player == null or class_resource_config == null:
		if class_resource_label != null:
			class_resource_label.visible = false
		return

	var resource_id: String = str(class_resource_config.get("resource_id"))
	var snapshot: Dictionary = player.get_resource_snapshot(resource_id)
	var current_value: int = int(snapshot.get("current", 0))
	var reference_value: int = int(snapshot.get("reference", int(class_resource_config.get("reference_value"))))
	var bonus_value: int = int(snapshot.get("bonus", 0))
	class_resource_bar.set_values(current_value, reference_value, bonus_value)
	if class_resource_label != null:
		class_resource_label.visible = true
		class_resource_label.text = _class_resource_text(current_value, reference_value)

func _class_resource_text(current_value: int, reference_value: int) -> String:
	if bool(class_resource_config.get("display_reference_value")):
		return "%s/%s" % [current_value, reference_value]

	return "%s" % current_value

func _current_run_memories() -> int:
	if _has_game_manager() and GameManager.current_run_data != null:
		return max(int(GameManager.current_run_data.memories), 0)

	return 0

func _connect_run_currency_signal() -> void:
	if not _has_game_manager():
		return
	if not GameManager.run_currencies_changed.is_connected(_on_run_currencies_changed):
		GameManager.run_currencies_changed.connect(_on_run_currencies_changed)

func _has_game_manager() -> bool:
	return get_node_or_null("/root/GameManager") != null

func _timeline_markers() -> Array[Dictionary]:
	var active_markers: Array[Dictionary] = []
	for entry in battle.action_queue:
		if entry.status == QueuedAction.STATUS_CANCELLED:
			continue
		if entry.actor == null or entry.action == null:
			continue

		active_markers.append({
			"time": _entry_time(entry),
			"initial": entry.actor.get_timeline_initial(),
			"action": entry.action.display_name,
			"color": entry.actor.get_timeline_color(),
			"status": entry.status,
			"order": _entry_order(entry),
		})

	active_markers.sort_custom(_sort_timeline_markers)
	return active_markers

func _entry_time(entry: QueuedAction) -> float:
	if entry.status == QueuedAction.STATUS_RESOLVED and entry.resolved_time >= 0.0:
		return entry.resolved_time

	return entry.resolve_time

func _entry_order(entry: QueuedAction) -> int:
	if entry.resolution_order > 0:
		return entry.resolution_order

	return entry.id

func _sort_timeline_markers(a: Dictionary, b: Dictionary) -> bool:
	var a_time: float = float(a.get("time", 0.0))
	var b_time: float = float(b.get("time", 0.0))
	if not is_equal_approx(a_time, b_time):
		return a_time < b_time

	return int(a.get("order", 0)) < int(b.get("order", 0))

func _format_speed(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(value))

	return str(value)

func _update_status_bar() -> void:
	if preview_status_atlas:
		status_entries = _preview_status_entries()
	else:
		status_entries = _active_player_status_entries()

	status_bar.visible = not status_entries.is_empty()
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

func _active_player_status_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if player == null:
		return entries

	for raw_status_id: Variant in player.statuses.keys():
		var status_id: String = str(raw_status_id)
		if not player.has_status(status_id):
			continue

		var state: Dictionary = player.statuses[status_id]
		var status_data: Resource = state.get("data", null) as Resource
		var display_name: String = status_id.capitalize()

		if status_data != null:
			var display_name_value: Variant = status_data.get("display_name")
			if not str(display_name_value).is_empty():
				display_name = str(display_name_value)

		entries.append({
			"id": status_id,
			"display_name": display_name,
			"remaining_seconds": player.get_status_remaining(status_id),
			"data": status_data,
		})

	StatusEntrySorterScript.sort_entries(entries)
	return entries

func _preview_status_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in range(preview_status_icon_count):
		entries.append({
			"id": "atlas_status_%s" % index,
			"display_name": _preview_status_display_name(index),
			"description": "Status atlas cell (%s, 0)." % index,
			"remaining_seconds": 0.0,
			"icon_atlas_coords": Vector2i(index, 0),
			"icon_atlas_cell_size": preview_status_icon_cell_size,
		})

	return entries

func _preview_status_display_name(index: int) -> String:
	match index:
		0:
			return "Vulnerable"
		1:
			return "Weaken"
		_:
			return "Atlas Status %s" % (index + 1)

func _ensure_status_button_count(count: int) -> void:
	while status_buttons.size() < count:
		var button: Control = StatusIconViewScene.instantiate() as Control
		button.name = "StatusButton%s" % status_buttons.size()
		status_icons.add_child(button)
		status_buttons.append(button)
		_bind_hover_source(button)

func _configure_static_hover_sources() -> void:
	_bind_hover_source(speed_button)
	_bind_hover_source(pause_button)

func _bind_hover_source(source: Control) -> void:
	hover_info_panel.call("bind_source", source)

func _show_hover_info_for_source(source: Control) -> void:
	hover_info_panel.call("show_for_source", source)

func _clear_hover_info() -> void:
	hover_info_panel.call("clear")

func _on_speed_button_pressed() -> void:
	speed_requested.emit()

func _on_pause_button_pressed() -> void:
	pause_requested.emit()

func _on_run_currencies_changed(_memories: int, _gold: int) -> void:
	_update_memory_bar()

func _on_hotbar_slot_selected(slot_id: StringName) -> void:
	var slot_entry: Dictionary = action_bar.get_slot_entry(slot_id)
	if slot_entry.is_empty():
		return

	hotbar_slot_used.emit(slot_id, slot_entry)
	var slot_kind: StringName = _slot_kind(slot_entry)
	if slot_kind != BattleActionBar.SLOT_KIND_ACTION:
		return

	var action_index: int = _action_index_from_slot(slot_entry)
	if action_index < 0:
		return

	action_selected.emit(action_index)

func _slot_kind(slot_entry: Dictionary) -> StringName:
	var kind_value: Variant = slot_entry.get(BattleActionBar.KIND_KEY, BattleActionBar.SLOT_KIND_EMPTY)
	if kind_value is StringName:
		return kind_value

	return StringName(str(kind_value))

func _action_index_from_slot(slot_entry: Dictionary) -> int:
	var action_index: int = int(slot_entry.get(BattleActionBar.ACTION_INDEX_KEY, -1))
	if action_index >= 0 and player != null and action_index < player.actions.size():
		return action_index

	var action_id: String = str(slot_entry.get(BattleActionBar.ACTION_ID_KEY, ""))
	if action_id.is_empty() or player == null:
		return -1

	for index in player.actions.size():
		var action: CombatActionData = player.actions[index]
		if action != null and action.id == action_id:
			return index

	return -1
