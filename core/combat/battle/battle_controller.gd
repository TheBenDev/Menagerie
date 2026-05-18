## Advances combat time, queues actions, resolves simultaneous actions, and requests player input.
class_name BattleController
extends Node

const CombatantGroupScript := preload("res://core/combat/combatant_group.gd")
const CombatBrainScript := preload("res://core/combat/ai/combat_brain.gd")
const CombatTargetingScript := preload("res://core/combat/actions/combat_targeting.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const DEFAULT_DIFFICULTY_PROFILE := preload("res://core/difficulty/normal.tres")
const PLAYER_GROUP_ID := "player"
const ENEMY_GROUP_ID := "enemy"

signal time_changed(current_time: float)
signal player_ready(player: Combatant)
signal player_group_defeated()
signal enemy_group_defeated()
signal battle_log(message: String)
signal time_scale_changed(time_scale: float)
signal pause_changed(is_paused: bool)
signal action_queue_changed()

var player: Combatant = null
var enemy: Combatant = null
var player_group: CombatantGroup = null
var enemy_group: CombatantGroup = null
@export var difficulty_profile: DifficultyProfile = null
var ai_controlled_combatants: Array[Combatant] = []

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
var player_starting_hp_override: int = -1
var player_starting_max_hp_override: int = -1
var action_queue: Array[QueuedAction] = []
var _next_queue_id: int = 1
var _next_resolution_order: int = 1

## Configures battle sides while preserving `player` and `enemy` as primary convenience references.
func configure_combatant_groups(player_combatants: Array, enemy_combatants: Array) -> void:
	player_group = CombatantGroupScript.new(PLAYER_GROUP_ID, player_combatants) as CombatantGroup
	enemy_group = CombatantGroupScript.new(ENEMY_GROUP_ID, enemy_combatants) as CombatantGroup
	_sync_convenience_refs_from_groups()

func set_ai_controlled_combatants(combatants: Array) -> void:
	ai_controlled_combatants.clear()
	for raw_combatant in combatants:
		var combatant := raw_combatant as Combatant
		if combatant != null and not ai_controlled_combatants.has(combatant):
			ai_controlled_combatants.append(combatant)

func get_player_combatants() -> Array[Combatant]:
	_ensure_combatant_groups()
	return player_group.combatants.duplicate()

func get_enemy_combatants() -> Array[Combatant]:
	_ensure_combatant_groups()
	return enemy_group.combatants.duplicate()

func get_living_player_combatants() -> Array[Combatant]:
	_ensure_combatant_groups()
	return player_group.get_living_combatants()

func get_living_enemy_combatants() -> Array[Combatant]:
	_ensure_combatant_groups()
	return enemy_group.get_living_combatants()

func is_player_group_defeated() -> bool:
	_ensure_combatant_groups()
	return player_group == null or not player_group.has_living_combatants()

func is_enemy_group_defeated() -> bool:
	_ensure_combatant_groups()
	return enemy_group == null or not enemy_group.has_living_combatants()

func start_battle() -> void:
	_ensure_combatant_groups()
	if player_group == null or player_group.is_empty() or enemy_group == null or enemy_group.is_empty():
		push_error("BattleController needs player and enemy combatant groups assigned.")
		return

	_connect_group_death_signals(player_group)
	_connect_group_death_signals(enemy_group)

	_reset_group_runtime_state(player_group)
	_reset_group_runtime_state(enemy_group)
	_apply_player_hp_override()
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
	if player != null and player.hp > 0:
		player_ready.emit(player)
	else:
		waiting_for_player_input = false
		_choose_ready_ai_actions()
		advance_until_input_needed()

func _ensure_combatant_groups() -> void:
	if player_group == null:
		player_group = CombatantGroupScript.new(PLAYER_GROUP_ID) as CombatantGroup
	if enemy_group == null:
		enemy_group = CombatantGroupScript.new(ENEMY_GROUP_ID) as CombatantGroup

	if player_group.is_empty() and player != null:
		player_group.add_combatant(player)
	if enemy_group.is_empty() and enemy != null:
		enemy_group.add_combatant(enemy)

	_sync_convenience_refs_from_groups()

func _sync_convenience_refs_from_groups() -> void:
	if player_group != null:
		var primary_player: Combatant = player
		if primary_player == null or not player_group.has_combatant(primary_player):
			primary_player = player_group.get_first_combatant()
		if primary_player != null:
			player = primary_player

	if enemy_group != null:
		var primary_enemy: Combatant = enemy_group.get_first_living_combatant()
		if primary_enemy == null:
			primary_enemy = enemy_group.get_first_combatant()
		if primary_enemy != null:
			enemy = primary_enemy

func _connect_group_death_signals(group: CombatantGroup) -> void:
	if group == null:
		return

	for combatant in group.combatants:
		if combatant != null and not combatant.died.is_connected(_on_combatant_died):
			combatant.died.connect(_on_combatant_died)

func _reset_group_runtime_state(group: CombatantGroup) -> void:
	if group == null:
		return

	for combatant in group.combatants:
		if combatant != null:
			combatant.reset_runtime_state()

func _tick_group_time(group: CombatantGroup, delta_seconds: float) -> void:
	if group == null:
		return

	for combatant in group.combatants:
		if combatant != null:
			combatant.tick_time(delta_seconds)

func _apply_player_hp_override() -> void:
	if player_starting_max_hp_override <= 0:
		return

	player.max_hp = max(player_starting_max_hp_override, 1)
	player.hp = clamp(player_starting_hp_override, 0, player.max_hp)
	player.hp_changed.emit(player)

func player_choose_action(action: CombatActionData, explicit_targets: Array[Combatant] = []) -> void:
	if battle_over or not waiting_for_player_input or action == null:
		return

	var targets: Array[Combatant] = _targets_for_player_action(action, explicit_targets)
	if targets.is_empty():
		return

	waiting_for_player_input = false
	player.start_action(action, targets, current_time)
	_enqueue_action(player, action)
	battle_log.emit(player.display_name + " starts " + action.display_name + ".")

	_choose_ready_ai_actions()

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

		_tick_group_time(player_group, tick_size)
		_tick_group_time(enemy_group, tick_size)

		_resolve_due_actions()

		if battle_over:
			break

		_choose_ready_ai_actions()

		_sync_convenience_refs_from_groups()
		if player != null and player.hp > 0 and not player.is_busy:
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

func _choose_ready_ai_actions() -> void:
	if battle_over:
		return

	for active_enemy in get_living_enemy_combatants():
		if active_enemy == null or active_enemy.is_busy:
			continue
		_ai_choose_action(active_enemy, enemy_group, player_group)

	for active_player in get_living_player_combatants():
		if active_player == null or active_player.is_busy or active_player == player:
			continue
		if not ai_controlled_combatants.has(active_player):
			continue
		_ai_choose_action(active_player, player_group, enemy_group)

func _ai_choose_action(actor: Combatant, ally_group: CombatantGroup, opponent_group: CombatantGroup) -> void:
	if actor == null or actor.hp <= 0:
		return

	var opponents: Array[Combatant] = opponent_group.get_living_combatants() if opponent_group != null else []
	var allies: Array[Combatant] = ally_group.get_living_combatants() if ally_group != null else []
	var choice := CombatBrainScript.choose_action(actor, opponents, allies, _active_difficulty_profile())
	if choice.is_empty():
		return

	var raw_action: Variant = choice.get("action", null)
	var action := raw_action as CombatActionData
	var targets := _combatant_targets_from(choice.get("targets", []))
	if action == null or targets.is_empty():
		return

	actor.start_action(action, targets, current_time)
	_enqueue_action(actor, action)
	battle_log.emit(actor.display_name + " starts " + action.display_name + ".")

func _active_difficulty_profile() -> DifficultyProfile:
	if difficulty_profile != null:
		return difficulty_profile

	return DEFAULT_DIFFICULTY_PROFILE as DifficultyProfile

func _apply_difficulty_profile() -> void:
	var active_difficulty: Resource = _active_difficulty_profile()
	for player_combatant in get_player_combatants():
		player_combatant.outgoing_damage_multiplier = 1.0
		player_combatant.action_time_multiplier = 1.0

	for enemy_combatant in get_enemy_combatants():
		_apply_enemy_difficulty_profile(enemy_combatant, active_difficulty)

func _apply_enemy_difficulty_profile(enemy_combatant: Combatant, active_difficulty: Resource) -> void:
	if enemy_combatant == null:
		return

	var base_enemy_hp: int = max(enemy_combatant.vitality, 1) * 10
	var health_multiplier := ValueReaderScript.resource_float(active_difficulty, "enemy_health_multiplier", 1.0)
	enemy_combatant.max_hp = max(int(round(float(base_enemy_hp) * health_multiplier)), 1)
	enemy_combatant.hp = enemy_combatant.max_hp
	enemy_combatant.block = 0
	enemy_combatant.outgoing_damage_multiplier = ValueReaderScript.resource_float(active_difficulty, "enemy_damage_multiplier", 1.0)
	enemy_combatant.action_time_multiplier = ValueReaderScript.resource_float(active_difficulty, "enemy_time_cost_multiplier", 1.0)
	enemy_combatant.hp_changed.emit(enemy_combatant)
	enemy_combatant.block_changed.emit(enemy_combatant)

func _targets_for_player_action(action: CombatActionData, explicit_targets: Array[Combatant]) -> Array[Combatant]:
	var opponents: Array[Combatant] = enemy_group.get_living_combatants() if enemy_group != null else []
	var allies: Array[Combatant] = player_group.get_living_combatants() if player_group != null else []
	return CombatTargetingScript.targets_for_action(action, player, opponents, allies, explicit_targets)

func _combatant_targets_from(raw_targets: Variant) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	if raw_targets is Array:
		for target in raw_targets:
			if target is Combatant:
				var combatant := target as Combatant
				if combatant.hp > 0:
					targets.append(combatant)

	return targets

func _on_combatant_died(combatant: Combatant) -> void:
	_cancel_pending_actions_for(combatant)
	battle_log.emit(combatant.display_name + " has fallen.")
	_sync_convenience_refs_from_groups()

	var players_defeated := is_player_group_defeated()
	var enemies_defeated := is_enemy_group_defeated()
	if not players_defeated and not enemies_defeated:
		if combatant == player:
			waiting_for_player_input = false
			_choose_ready_ai_actions()
			advance_until_input_needed()
		return

	battle_over = true
	waiting_for_player_input = false
	set_paused(false)
	if players_defeated:
		player_group_defeated.emit()
	if enemies_defeated:
		enemy_group_defeated.emit()

func _enqueue_action(actor: Combatant, action: CombatActionData) -> void:
	var entry := QueuedAction.new(
		_next_queue_id,
		actor,
		action,
		actor.action_finish_time
	)
	_next_queue_id += 1
	action_queue.append(entry)
	action_queue_changed.emit()

func _cancel_pending_actions_for(combatant: Combatant) -> void:
	if combatant == null:
		return

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
