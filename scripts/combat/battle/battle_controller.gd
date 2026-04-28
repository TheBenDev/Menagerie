class_name BattleController
extends Node

const EnemyBrainScript := preload("res://scripts/combat/ai/enemy_brain.gd")
const DEFAULT_DIFFICULTY_PROFILE := preload("res://data/difficulty/normal.tres")
const CombatTime := preload("res://scripts/combat/time/combat_time.gd")

signal time_changed(current_time: float)
signal player_ready(player: Combatant)
signal battle_log(message: String)
signal time_scale_changed(time_scale: float)
signal pause_changed(is_paused: bool)
signal action_queue_changed()

var player: Combatant = null
var enemy: Combatant = null
@export var difficulty_profile: DifficultyProfile = null

var current_time: float = 0.0
var tick_size: float = CombatTime.TIME_STEP_SECONDS
var seconds_per_tick: float = 1.0
var time_scale: float = 1.0
var time_scale_index: int = 1
var time_scale_values: Array[float] = [0.5, 1.0, 2.0, 4.0]

var waiting_for_player_input: bool = false
var battle_over: bool = false
var is_advancing: bool = false
var is_paused: bool = false
var action_queue: Array[QueuedAction] = []
var _next_queue_id: int = 1
var _next_resolution_order: int = 1

func start_battle() -> void:
	if player == null or enemy == null:
		push_error("BattleController needs player and enemy assigned.")
		return

	if not player.died.is_connected(_on_combatant_died):
		player.died.connect(_on_combatant_died)
	if not enemy.died.is_connected(_on_combatant_died):
		enemy.died.connect(_on_combatant_died)

	player.reset_runtime_state()
	enemy.reset_runtime_state()
	_apply_difficulty_profile()

	current_time = 0.0
	battle_over = false
	waiting_for_player_input = true
	set_paused(false)
	action_queue.clear()
	_next_queue_id = 1
	_next_resolution_order = 1
	action_queue_changed.emit()

	battle_log.emit("Battle started.")
	player_ready.emit(player)

func player_choose_action(action: CombatActionData) -> void:
	if battle_over or not waiting_for_player_input or action == null:
		return

	var targets: Array[Combatant] = []
	targets.append(enemy if action.target_enemy else player)

	waiting_for_player_input = false
	player.start_action(action, targets, current_time)
	_enqueue_action(player, action, targets)
	battle_log.emit(player.display_name + " starts " + action.display_name + ".")

	if not enemy.is_busy:
		_enemy_choose_action()

	advance_until_input_needed()

func cycle_time_scale() -> void:
	time_scale_index = (time_scale_index + 1) % time_scale_values.size()
	set_time_scale(float(time_scale_values[time_scale_index]))

func set_time_scale(new_time_scale: float) -> void:
	time_scale = max(new_time_scale, 0.01)
	time_scale_changed.emit(time_scale)

func toggle_pause() -> void:
	set_paused(not is_paused)

func set_paused(new_is_paused: bool) -> void:
	if is_paused == new_is_paused:
		return

	is_paused = new_is_paused
	pause_changed.emit(is_paused)

func advance_until_input_needed() -> void:
	if is_advancing:
		return

	is_advancing = true
	var should_emit_player_ready := false

	while not waiting_for_player_input and not battle_over:
		var tick_delay_seconds := _tick_delay_seconds()
		if tick_delay_seconds > 0.0:
			await _wait_tick_delay(tick_delay_seconds)

		if waiting_for_player_input or battle_over:
			break

		current_time = CombatTime.snap_absolute_time(current_time + tick_size)
		time_changed.emit(current_time)

		player.tick_time(tick_size)
		enemy.tick_time(tick_size)

		_resolve_due_actions()

		if battle_over:
			break

		if not enemy.is_busy:
			_enemy_choose_action()

		if not player.is_busy:
			waiting_for_player_input = true
			should_emit_player_ready = true
			break

	is_advancing = false
	if should_emit_player_ready:
		player_ready.emit(player)
	else:
		time_changed.emit(current_time)

func _tick_delay_seconds() -> float:
	return seconds_per_tick * tick_size / max(time_scale, 0.01)

func _wait_tick_delay(delay_seconds: float) -> void:
	var elapsed_seconds := 0.0
	var last_tick_usec := Time.get_ticks_usec()

	while elapsed_seconds < delay_seconds and not waiting_for_player_input and not battle_over:
		await get_tree().process_frame

		var current_tick_usec := Time.get_ticks_usec()
		var delta_seconds := float(current_tick_usec - last_tick_usec) / 1000000.0
		last_tick_usec = current_tick_usec

		if not is_paused:
			elapsed_seconds += delta_seconds

func _enemy_choose_action() -> void:
	if enemy.hp <= 0:
		return

	var opponents: Array[Combatant] = []
	if player != null:
		opponents.append(player)

	var allies: Array[Combatant] = []
	if enemy != null:
		allies.append(enemy)

	var choice := EnemyBrainScript.choose_action(enemy, opponents, allies, _active_difficulty_profile())
	if choice.is_empty():
		return

	var raw_action: Variant = choice.get("action", null)
	var action := raw_action as CombatActionData
	var targets := _combatant_targets_from(choice.get("targets", []))
	if action == null or targets.is_empty():
		return

	enemy.start_action(action, targets, current_time)
	_enqueue_action(enemy, action, targets)
	battle_log.emit(enemy.display_name + " starts " + action.display_name + ".")

func _active_difficulty_profile() -> DifficultyProfile:
	if difficulty_profile != null:
		return difficulty_profile

	return DEFAULT_DIFFICULTY_PROFILE as DifficultyProfile

func _apply_difficulty_profile() -> void:
	var active_difficulty: Resource = _active_difficulty_profile()
	if player != null:
		player.outgoing_damage_multiplier = 1.0
		player.action_time_multiplier = 1.0

	if enemy == null:
		return

	var base_enemy_hp: int = max(enemy.vitality, 1) * 10
	var health_multiplier := _difficulty_float(active_difficulty, "enemy_health_multiplier", 1.0)
	enemy.max_hp = max(int(round(float(base_enemy_hp) * health_multiplier)), 1)
	enemy.hp = enemy.max_hp
	enemy.block = 0
	enemy.outgoing_damage_multiplier = _difficulty_float(active_difficulty, "enemy_damage_multiplier", 1.0)
	enemy.action_time_multiplier = _difficulty_float(active_difficulty, "enemy_time_cost_multiplier", 1.0)
	enemy.hp_changed.emit(enemy)
	enemy.block_changed.emit(enemy)

func _difficulty_float(active_difficulty: Resource, field_name: String, default_value: float) -> float:
	if active_difficulty == null:
		return default_value

	var value: Variant = active_difficulty.get(field_name)
	if value is int or value is float:
		return float(value)

	return default_value

func _combatant_targets_from(raw_targets: Variant) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	if raw_targets is Array:
		for target in raw_targets:
			if target is Combatant:
				targets.append(target)

	return targets

func _on_combatant_died(combatant: Combatant) -> void:
	battle_over = true
	waiting_for_player_input = false
	set_paused(false)
	_cancel_pending_actions_for(combatant)
	battle_log.emit(combatant.display_name + " has fallen.")

func _enqueue_action(actor: Combatant, action: CombatActionData, targets: Array[Combatant]) -> void:
	var entry := QueuedAction.new(
		_next_queue_id,
		actor,
		action,
		targets,
		current_time,
		actor.action_finish_time
	)
	_next_queue_id += 1
	action_queue.append(entry)
	action_queue_changed.emit()

func _cancel_pending_actions_for(combatant: Combatant) -> void:
	var cancelled_any := false
	for entry in action_queue:
		if entry.is_pending() and entry.actor == combatant:
			entry.status = QueuedAction.STATUS_CANCELLED
			entry.resolved_time = current_time
			cancelled_any = true

	combatant.cancel_pending_action()

	if cancelled_any:
		action_queue_changed.emit()

func _resolve_due_actions() -> void:
	var due_entries: Array[QueuedAction] = []
	for entry in action_queue:
		if entry.is_pending() and CombatTime.is_due(entry.resolve_time, current_time):
			due_entries.append(entry)

	if due_entries.is_empty():
		return

	var ordered_entries := _order_due_actions(due_entries)
	for entry in ordered_entries:
		if battle_over:
			break
		_resolve_queue_entry(entry)

	action_queue_changed.emit()

func _order_due_actions(entries: Array[QueuedAction]) -> Array[QueuedAction]:
	var ordered_entries: Array[QueuedAction] = []
	var remaining_entries := entries.duplicate()

	while not remaining_entries.is_empty():
		var earliest_resolve_time := _earliest_resolve_time_in(remaining_entries)
		var time_group: Array[QueuedAction] = []
		var later_entries: Array[QueuedAction] = []
		for entry in remaining_entries:
			if is_equal_approx(entry.resolve_time, earliest_resolve_time):
				time_group.append(entry)
			else:
				later_entries.append(entry)

		ordered_entries.append_array(_order_same_tick_actions(time_group))
		remaining_entries = later_entries

	return ordered_entries

func _order_same_tick_actions(entries: Array[QueuedAction]) -> Array[QueuedAction]:
	var ordered_entries: Array[QueuedAction] = []
	var remaining_entries := entries.duplicate()

	while not remaining_entries.is_empty():
		var highest_dex := _highest_dex_in(remaining_entries)
		var dex_group: Array[QueuedAction] = []
		var next_remaining: Array[QueuedAction] = []
		for entry in remaining_entries:
			if entry.actor.dexterity == highest_dex:
				dex_group.append(entry)
			else:
				next_remaining.append(entry)

		if dex_group.size() == 1:
			ordered_entries.append(dex_group[0])
		else:
			ordered_entries.append_array(_order_dex_tie(dex_group))

		remaining_entries = next_remaining

	return ordered_entries

func _earliest_resolve_time_in(entries: Array[QueuedAction]) -> float:
	var earliest_resolve_time := INF
	for entry in entries:
		earliest_resolve_time = min(earliest_resolve_time, entry.resolve_time)
	return earliest_resolve_time

func _highest_dex_in(entries: Array[QueuedAction]) -> int:
	var highest_dex := -1
	for entry in entries:
		highest_dex = max(highest_dex, entry.actor.dexterity)
	return highest_dex

func _order_dex_tie(entries: Array[QueuedAction]) -> Array[QueuedAction]:
	var ordered_entries: Array[QueuedAction] = []
	var remaining_entries := entries.duplicate()

	while remaining_entries.size() > 1:
		var highest_roll := 0
		var winners: Array[QueuedAction] = []
		for entry in remaining_entries:
			var roll := randi_range(1, 6)
			entry.tie_rolls.append(roll)
			if roll > highest_roll:
				highest_roll = roll
				winners = [entry]
			elif roll == highest_roll:
				winners.append(entry)

		if winners.size() == 1:
			var winner := winners[0]
			ordered_entries.append(winner)
			remaining_entries.erase(winner)
		else:
			var tied_names: Array[String] = []
			for winner in winners:
				tied_names.append("%s rolled %s" % [winner.actor.display_name, winner.tie_rolls.back()])
			battle_log.emit("DEX tie reroll: %s." % ", ".join(tied_names))

	if remaining_entries.size() == 1:
		ordered_entries.append(remaining_entries[0])

	return ordered_entries

func _resolve_queue_entry(entry: QueuedAction) -> void:
	if not entry.is_pending():
		return

	if entry.actor.hp <= 0:
		entry.status = QueuedAction.STATUS_CANCELLED
		action_queue_changed.emit()
		return

	if not entry.actor.is_busy or entry.actor.pending_action != entry.action:
		entry.status = QueuedAction.STATUS_CANCELLED
		action_queue_changed.emit()
		return

	var roll_suffix := ""
	if not entry.tie_rolls.is_empty():
		roll_suffix = " (tie roll %s)" % entry.tie_rolls.back()

	battle_log.emit("%s resolves %s%s." % [entry.actor.display_name, entry.action.display_name, roll_suffix])
	entry.actor.resolve_pending_action()
	entry.status = QueuedAction.STATUS_RESOLVED
	entry.resolved_time = current_time
	entry.resolution_order = _next_resolution_order
	_next_resolution_order += 1
