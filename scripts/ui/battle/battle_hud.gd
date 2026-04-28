class_name BattleHUD
extends Control

const CombatantPanelScript := preload("res://scripts/ui/battle/combatant_panel.gd")
const BattleActionBarScript := preload("res://scripts/ui/battle/action_bar.gd")
const ActionQueuePanelScript := preload("res://scripts/ui/battle/action_queue_panel.gd")
const NumberFontHelper := preload("res://scripts/ui/common/number_font.gd")

signal action_selected(index: int)
signal speed_requested()
signal pause_requested()

@onready var timeline_view: TimelineView = $MarginContainer/Layout/TimelineRow/TimelinePanel/TimelineMargin/Timeline
@onready var speed_button: Button = $MarginContainer/Layout/TimelineRow/TimeControls/SpeedButton
@onready var pause_button: Button = $MarginContainer/Layout/TimelineRow/TimeControls/PauseButton
@onready var prompt_label: Label = $MarginContainer/Layout/ContentRow/MainColumn/PromptLabel
@onready var player_panel: CombatantPanelScript = $MarginContainer/Layout/ContentRow/MainColumn/CombatantsRow/PlayerPanel
@onready var enemy_panel: CombatantPanelScript = $MarginContainer/Layout/ContentRow/MainColumn/CombatantsRow/EnemyPanel
@onready var action_bar: BattleActionBarScript = $MarginContainer/Layout/ContentRow/MainColumn/ActionBar
@onready var action_queue_panel: ActionQueuePanelScript = $MarginContainer/Layout/ContentRow/ActionQueuePanel

var battle: BattleController = null
var player: Combatant = null
var enemy: Combatant = null

func _ready() -> void:
	speed_button.pressed.connect(_on_speed_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	action_bar.action_selected.connect(_on_action_selected)
	NumberFontHelper.apply_to_button(speed_button)

func setup(new_battle: BattleController, new_player: Combatant, new_enemy: Combatant) -> void:
	battle = new_battle
	player = new_player
	enemy = new_enemy

	player_panel.setup(player)
	enemy_panel.setup(enemy)
	_align_resource_slots()
	action_bar.set_actions(player.actions)
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
	player_panel.refresh()
	enemy_panel.refresh()
	action_bar.set_can_choose(battle.waiting_for_player_input and not battle.battle_over)
	action_queue_panel.refresh(battle.action_queue)
	_update_prompt()

func choose_action_index(index: int) -> void:
	action_bar.choose_action_index(index)

func _align_resource_slots() -> void:
	var slot_count: int = max(player_panel.get_extra_resource_count(), enemy_panel.get_extra_resource_count())
	player_panel.set_resource_slot_count(slot_count)
	enemy_panel.set_resource_slot_count(slot_count)

func _update_prompt() -> void:
	if battle.battle_over:
		prompt_label.text = "Battle complete."
	elif battle.waiting_for_player_input:
		prompt_label.text = "Choose an action."
	else:
		prompt_label.text = "Time is advancing..."

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
	var a_time := float(a.get("time", 0.0))
	var b_time := float(b.get("time", 0.0))
	if not is_equal_approx(a_time, b_time):
		return a_time < b_time

	return int(a.get("order", 0)) < int(b.get("order", 0))

func _format_speed(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(value))

	return str(value)

func _on_speed_button_pressed() -> void:
	speed_requested.emit()

func _on_pause_button_pressed() -> void:
	pause_requested.emit()

func _on_action_selected(index: int) -> void:
	action_selected.emit(index)
