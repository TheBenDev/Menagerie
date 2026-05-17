## Scene coordinator that wires combatants, HUD, audio, run data, and final combat result reporting.
extends Node

const CombatResultScript := preload("res://core/combat/combat_result.gd")
const BattleHudScript := preload("res://scenes/combat/ui/battle_hud.gd")
const CombatAudioBridgeScript := preload("res://core/audio/combat_audio_bridge.gd")
const CombatantDisplayScript := preload("res://scenes/combat/ui/combatant_display.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")

const DEFAULT_PLAYER_SLOT_ID := &"PlayerSlot1"
const DEFAULT_ENEMY_SLOT_ID := &"EnemySlot1"

@onready var battle: BattleController = $BattleController
@onready var warrior: WarriorCombatant = $Warrior
@onready var enemy: EnemyCombatant = $Enemy
@onready var warrior_display: CombatantDisplayScript = $WarriorDisplay
@onready var enemy_display: CombatantDisplayScript = $EnemyDisplay
@onready var player_slots: Control = $PlayerSlots
@onready var enemy_slots: Control = $EnemySlots
@onready var hud: Control = $BattleHUD

var actions_used: int = 0
var combat_result_reported: bool = false
var last_accounted_combat_time: float = 0.0
var audio_bridge: Node = null
var run_player_hp_before_combat: int = 0
var active_enemy_slot_id: StringName = DEFAULT_ENEMY_SLOT_ID
var pending_player_action: CombatActionData = null
var targeting_valid_targets: Array[Combatant] = []

func _ready() -> void:
	_configure_encounter_from_game_manager()
	warrior.apply_profile()
	_apply_run_player_state()
	enemy.apply_profile()
	_apply_boss_overrides()

	battle.player = warrior
	battle.enemy = enemy
	battle.configure_combatant_groups([warrior], [enemy])

	if hud.get_script() == null:
		hud.set_script(BattleHudScript)

	hud.call("setup", battle, warrior, enemy, battle.player_group, battle.enemy_group)
	_apply_combatant_display_slots()
	warrior_display.setup(warrior)
	enemy_display.setup(enemy)
	_connect_combatant_display_signals()
	hud.connect("action_selected", Callable(self, "_choose_warrior_action"))
	hud.connect("speed_requested", Callable(self, "_on_speed_requested"))
	hud.connect("pause_requested", Callable(self, "_on_pause_requested"))

	_connect_battle_signals()
	_connect_group_combatant_signals(battle.player_group)
	_connect_group_combatant_signals(battle.enemy_group)
	_connect_combat_result_signals()
	_connect_run_signals()

	battle.start_battle()
	if run_player_hp_before_combat <= 0:
		run_player_hp_before_combat = warrior.max_hp
	_setup_audio_bridge()
	_refresh_hud()

func _input(event: InputEvent) -> void:
	if _handle_targeting_input(event):
		return

	if not battle.waiting_for_player_input or _is_targeting():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var index := _action_index_for_key(event.keycode)
		if index >= 0:
			hud.call("choose_action_index", index)

func _connect_battle_signals() -> void:
	battle.time_changed.connect(_refresh_hud)
	battle.time_changed.connect(_on_battle_time_changed)
	battle.player_ready.connect(_refresh_hud)
	battle.battle_log.connect(_refresh_hud)
	battle.time_scale_changed.connect(_refresh_hud)
	battle.pause_changed.connect(_refresh_hud)
	battle.action_queue_changed.connect(_refresh_hud)

func _connect_combatant_signals(combatant: Combatant) -> void:
	if combatant == null:
		return

	combatant.hp_changed.connect(_refresh_hud)
	combatant.block_changed.connect(_refresh_hud)
	combatant.statuses_changed.connect(_refresh_hud)
	combatant.action_started.connect(_refresh_hud)
	combatant.action_resolved.connect(_refresh_hud)
	combatant.died.connect(_refresh_hud)

	if combatant.has_signal("rage_changed"):
		combatant.connect("rage_changed", Callable(self, "_refresh_hud"))

func _connect_group_combatant_signals(group: Variant) -> void:
	if group == null:
		return

	for combatant in group.combatants:
		_connect_combatant_signals(combatant)

func _connect_combat_result_signals() -> void:
	if not battle.player_group_defeated.is_connected(_on_player_group_defeated):
		battle.player_group_defeated.connect(_on_player_group_defeated)
	if not battle.enemy_group_defeated.is_connected(_on_enemy_group_defeated):
		battle.enemy_group_defeated.connect(_on_enemy_group_defeated)

func _connect_run_signals() -> void:
	if not _has_game_manager():
		return

	if not GameManager.run_ended.is_connected(_on_run_ended):
		GameManager.run_ended.connect(_on_run_ended)

func _connect_combatant_display_signals() -> void:
	if not warrior_display.target_selected.is_connected(_on_target_display_selected):
		warrior_display.target_selected.connect(_on_target_display_selected)
	if not enemy_display.target_selected.is_connected(_on_target_display_selected):
		enemy_display.target_selected.connect(_on_target_display_selected)

func _setup_audio_bridge() -> void:
	audio_bridge = CombatAudioBridgeScript.new()
	audio_bridge.name = "CombatAudioBridge"
	add_child(audio_bridge)
	var encounter := GameManager.get_current_encounter() if _has_game_manager() else {}
	audio_bridge.call("setup", battle, warrior, enemy, bool(encounter.get("is_boss", false)), battle.player_group, battle.enemy_group)

## Starts explicit player targeting for the selected hotbar action.
func _choose_warrior_action(index: int) -> void:
	if _is_targeting() or not battle.waiting_for_player_input or battle.battle_over:
		return
	if index < 0 or index >= warrior.actions.size():
		return

	var action: CombatActionData = warrior.actions[index]
	var valid_targets := _valid_player_targets_for_action(action)
	if valid_targets.is_empty():
		return

	pending_player_action = action
	targeting_valid_targets = valid_targets
	hud.call("set_targeting_active", true)
	_apply_targeting_display_states()
	_refresh_hud()

func _on_speed_requested() -> void:
	battle.cycle_time_scale()

func _on_pause_requested() -> void:
	battle.toggle_pause()

func _on_battle_time_changed(current_time: float) -> void:
	var elapsed_seconds: float = max(current_time - last_accounted_combat_time, 0.0)
	last_accounted_combat_time = max(last_accounted_combat_time, current_time)

	if elapsed_seconds <= 0.0 or combat_result_reported or not _has_game_manager():
		return

	if not GameManager.advance_run_time(elapsed_seconds):
		combat_result_reported = true

func _refresh_hud(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	hud.call("refresh")
	warrior_display.refresh()
	enemy_display.refresh()

func _handle_targeting_input(event: InputEvent) -> bool:
	if not _is_targeting():
		return false

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_targeting()
			get_viewport().set_input_as_handled()
			return true

	if event.is_action_pressed("ui_cancel") or _is_targeting_cancel_key(event):
		_cancel_targeting()
		get_viewport().set_input_as_handled()
		return true

	if event.is_action_pressed("ui_accept") or _is_targeting_accept_key(event):
		if targeting_valid_targets.size() == 1:
			_confirm_targeting_target(targeting_valid_targets[0])
			get_viewport().set_input_as_handled()
			return true
		return true

	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed

	return false

func _is_targeting_cancel_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_BACKSPACE)

func _is_targeting_accept_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE)

func _is_targeting() -> bool:
	return pending_player_action != null

func _on_target_display_selected(selected_target: Combatant) -> void:
	_confirm_targeting_target(selected_target)

## Confirms a chosen target and queues the pending player action with explicit targets.
func _confirm_targeting_target(selected_target: Combatant) -> void:
	if not _is_targeting() or selected_target == null or not targeting_valid_targets.has(selected_target):
		return

	var action := pending_player_action
	var explicit_targets: Array[Combatant] = []
	explicit_targets.append(selected_target)
	_cancel_targeting(false)

	var was_waiting_for_input := battle.waiting_for_player_input
	battle.player_choose_action(action, explicit_targets)
	if was_waiting_for_input and not battle.waiting_for_player_input:
		actions_used += 1
	_refresh_hud()

func _cancel_targeting(refresh_after_cancel: bool = true) -> void:
	if not _is_targeting() and targeting_valid_targets.is_empty():
		return

	pending_player_action = null
	targeting_valid_targets.clear()
	_clear_targeting_display_states()
	hud.call("set_targeting_active", false)
	if refresh_after_cancel:
		_refresh_hud()

func _valid_player_targets_for_action(action: CombatActionData) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	if battle == null or action == null:
		return targets

	var target_group: Variant = battle.enemy_group if action.target_enemy else battle.player_group
	if target_group == null:
		return targets

	for combatant in target_group.get_living_combatants():
		if combatant != null and not targets.has(combatant):
			targets.append(combatant)

	return targets

func _apply_targeting_display_states() -> void:
	for entry in _combatant_display_entries():
		var display: Control = entry.get("display", null) as Control
		var combatant: Combatant = entry.get("combatant", null) as Combatant
		if display != null and display.has_method("set_targeting_state"):
			var can_target := combatant != null and targeting_valid_targets.has(combatant)
			display.call("set_targeting_state", can_target, can_target)

func _clear_targeting_display_states() -> void:
	for entry in _combatant_display_entries():
		var display: Control = entry.get("display", null) as Control
		if display != null and display.has_method("clear_targeting_state"):
			display.call("clear_targeting_state")

func _combatant_display_entries() -> Array[Dictionary]:
	return [
		{
			"combatant": warrior,
			"display": warrior_display,
		},
		{
			"combatant": enemy,
			"display": enemy_display,
		},
	]

func _action_index_for_key(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return int(keycode - KEY_1)

	return -1

func _configure_encounter_from_game_manager() -> void:
	active_enemy_slot_id = DEFAULT_ENEMY_SLOT_ID

	if not _has_game_manager():
		return

	var encounter := GameManager.get_current_encounter()
	var combat_encounter_profile := _combat_encounter_profile_for(encounter)
	active_enemy_slot_id = _enemy_slot_id_for_encounter(combat_encounter_profile)

	var enemy_profile_path: String = _enemy_profile_path_for_encounter(encounter, combat_encounter_profile)
	if not enemy_profile_path.is_empty():
		var enemy_profile := load(enemy_profile_path) as CombatantProfile
		if enemy_profile != null:
			enemy.profile = enemy_profile

	battle.difficulty_profile = GameManager.get_selected_difficulty_profile()

func _combat_encounter_profile_for(encounter: Dictionary) -> Resource:
	var profile_path := str(encounter.get("combat_encounter_profile_path", "")).strip_edges()
	if not profile_path.is_empty():
		var profile := load(profile_path) as Resource
		if profile != null:
			return profile

	var encounter_id: StringName = ValueReaderScript.string_name_from_variant(encounter.get("combat_encounter_id", &""))
	if _has_game_manager() and not String(encounter_id).is_empty():
		return GameManager.get_dungeon_combat_encounter(encounter_id)

	return null

func _enemy_profile_path_for_encounter(encounter: Dictionary, combat_encounter_profile: Resource) -> String:
	if combat_encounter_profile != null:
		if combat_encounter_profile.has_method("primary_enemy_profile_path"):
			var profile_path := str(combat_encounter_profile.call("primary_enemy_profile_path")).strip_edges()
			if not profile_path.is_empty():
				return profile_path

		var enemy_slots_value: Variant = combat_encounter_profile.get("enemy_slots")
		if not (enemy_slots_value is Array):
			return str(encounter.get("enemy_profile_path", "")).strip_edges()

		for slot in enemy_slots_value:
			if not (slot is Dictionary):
				continue
			var slot_data: Dictionary = slot
			var slot_profile_path := str(slot_data.get("combatant_profile_path", "")).strip_edges()
			if not slot_profile_path.is_empty():
				return slot_profile_path

	return str(encounter.get("enemy_profile_path", "")).strip_edges()

## Returns the authored enemy-side display slot for the current combat encounter.
func _enemy_slot_id_for_encounter(combat_encounter_profile: Resource) -> StringName:
	if combat_encounter_profile == null:
		return DEFAULT_ENEMY_SLOT_ID

	var enemy_slots_value: Variant = combat_encounter_profile.get("enemy_slots")
	if not (enemy_slots_value is Array):
		return DEFAULT_ENEMY_SLOT_ID

	for slot: Variant in enemy_slots_value:
		if not (slot is Dictionary):
			continue
		var slot_data: Dictionary = slot
		var position_id := ValueReaderScript.string_name_from_variant(slot_data.get("position_id", &""))
		if not String(position_id).is_empty():
			return position_id

	return DEFAULT_ENEMY_SLOT_ID

## Places the current primary combatant displays at authored combat slot markers.
func _apply_combatant_display_slots() -> void:
	#; Current combat still uses one player and one enemy display, positioned from authored markers.
	_apply_display_slot(warrior_display, player_slots, DEFAULT_PLAYER_SLOT_ID, DEFAULT_PLAYER_SLOT_ID)
	_apply_display_slot(enemy_display, enemy_slots, active_enemy_slot_id, DEFAULT_ENEMY_SLOT_ID)

## Copies an authored slot marker rectangle onto a display node.
func _apply_display_slot(display: Control, slot_parent: Control, slot_id: StringName, fallback_slot_id: StringName) -> void:
	if display == null or slot_parent == null:
		return

	var slot_marker := _slot_marker(slot_parent, slot_id)
	if slot_marker == null and slot_id != fallback_slot_id:
		slot_marker = _slot_marker(slot_parent, fallback_slot_id)
	if slot_marker == null:
		return

	var slot_rect := slot_marker.get_rect()
	display.offset_left = slot_rect.position.x
	display.offset_top = slot_rect.position.y
	display.offset_right = slot_rect.position.x + slot_rect.size.x
	display.offset_bottom = slot_rect.position.y + slot_rect.size.y

func _slot_marker(slot_parent: Control, slot_id: StringName) -> Control:
	if slot_parent == null or String(slot_id).is_empty():
		return null

	return slot_parent.get_node_or_null(NodePath(String(slot_id))) as Control

func _apply_run_player_state() -> void:
	if not _has_game_manager():
		return

	GameManager.apply_run_player_state_to_combatant(warrior)
	var hp_snapshot: Dictionary = GameManager.get_run_player_hp_snapshot()
	run_player_hp_before_combat = int(hp_snapshot.get("current", warrior.max_hp))
	battle.player_starting_hp_override = run_player_hp_before_combat
	battle.player_starting_max_hp_override = int(hp_snapshot.get("max", warrior.max_hp))

func _apply_boss_overrides() -> void:
	if not _has_game_manager() or not bool(GameManager.get_current_encounter().get("is_boss", false)):
		return

	enemy.display_name = "Training Boss"
	enemy.strength += 2
	enemy.vitality += 4

func _on_enemy_group_defeated() -> void:
	_finish_combat(true)

func _on_player_group_defeated() -> void:
	_finish_combat(false)

func _on_run_ended(reason: String) -> void:
	if reason != RunData.END_REASON_TIMEOUT or combat_result_reported:
		return

	_cancel_targeting(false)
	var encounter := GameManager.get_current_encounter() if _has_game_manager() else {}
	combat_result_reported = true
	var result: Variant = CombatResultScript.new()
	result.victory = false
	result.node_id = int(encounter.get("node_id", -1))
	result.is_boss = bool(encounter.get("is_boss", false))
	result.enemy_defeated = battle.is_enemy_group_defeated()
	result.player_defeated = battle.is_player_group_defeated()
	result.damage_dealt = _group_missing_hp(battle.enemy_group, enemy)
	result.damage_taken = max(run_player_hp_before_combat - warrior.hp, 0)
	result.actions_used = actions_used
	result.time_elapsed = battle.current_time
	_populate_player_hp_result(result)
	result.end_reason = reason

	if _has_game_manager() and GameManager.current_run_data != null:
		GameManager.current_run_data.register_combat_result(result)
		GameManager.emit_run_state()

func _finish_combat(victory: bool) -> void:
	if combat_result_reported:
		return

	_cancel_targeting(false)
	combat_result_reported = true
	var encounter := GameManager.get_current_encounter() if _has_game_manager() else {}
	var result: Variant = CombatResultScript.new()
	result.victory = victory
	result.node_id = int(encounter.get("node_id", -1))
	result.is_boss = bool(encounter.get("is_boss", false))
	result.enemy_defeated = battle.is_enemy_group_defeated()
	result.player_defeated = battle.is_player_group_defeated()
	result.damage_dealt = _group_missing_hp(battle.enemy_group, enemy)
	result.damage_taken = max(run_player_hp_before_combat - warrior.hp, 0)
	result.actions_used = actions_used
	result.time_elapsed = battle.current_time
	_populate_player_hp_result(result)
	result.end_reason = "" if victory else RunData.END_REASON_DEFEAT

	if not _has_game_manager():
		return

	if victory:
		var rewards: Dictionary = GameManager.calculate_rewards_for_profile(enemy.profile, result.is_boss)
		result.memories_awarded = int(rewards.get("memories_awarded", 0))
		result.gold_awarded = int(rewards.get("gold_awarded", 0))

	await get_tree().create_timer(1.0).timeout
	GameManager.complete_combat(result)

func _populate_player_hp_result(result: Variant) -> void:
	if result == null:
		return

	result.player_hp_before = run_player_hp_before_combat
	result.player_hp_after = warrior.hp
	result.player_max_hp = warrior.max_hp

func _group_missing_hp(group: Variant, fallback_combatant: Combatant) -> int:
	var total_missing_hp := 0
	if group != null:
		for combatant in group.combatants:
			if combatant != null:
				total_missing_hp += max(combatant.max_hp - combatant.hp, 0)
		return total_missing_hp

	if fallback_combatant == null:
		return 0

	return max(fallback_combatant.max_hp - fallback_combatant.hp, 0)

func _has_game_manager() -> bool:
	return get_node_or_null("/root/GameManager") != null
