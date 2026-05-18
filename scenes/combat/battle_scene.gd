## Scene coordinator that wires combatant groups, HUD, audio, run data, and final combat result reporting.
extends Node

const CombatResultScript := preload("res://core/combat/combat_result.gd")
const CombatantStatAllocatorScript := preload("res://core/combat/combatant_stat_allocator.gd")
const CombatTargetingScript := preload("res://core/combat/actions/combat_targeting.gd")
const BattleHudScript := preload("res://scenes/combat/ui/battle_hud.gd")
const CombatAudioBridgeScript := preload("res://core/audio/combat_audio_bridge.gd")
const CombatantDisplayScene := preload("res://scenes/combat/ui/CombatantDisplay.tscn")
const CombatantDisplayScript := preload("res://scenes/combat/ui/combatant_display.gd")
const CombatantScript := preload("res://scenes/combatants/combatant.gd")
const EnemyCombatantScript := preload("res://scenes/combatants/enemies/enemy_combatant.gd")
const WarriorCombatantScript := preload("res://scenes/combatants/characters/warrior/warrior_combatant.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const DEFAULT_PLAYER_PROFILE := preload("res://scenes/combatants/characters/warrior/warrior_profile.tres")

const DEFAULT_PLAYER_SLOT_ID := &"PlayerSlot1"
const DEFAULT_ENEMY_SLOT_ID := &"EnemySlot1"
const PLAYER_SLOT_IDS := [&"PlayerSlot1", &"PlayerSlot2", &"PlayerSlot3"]
const ENEMY_SLOT_IDS := [&"EnemySlot1", &"EnemySlot2", &"EnemySlot3", &"EnemySlot4"]
const TEMPORARY_PLAYER_AI_COPY_COUNT := 2

@onready var battle: BattleController = $BattleController
@onready var combatants_root: Node = $Combatants
@onready var combatant_displays_root: Node = $CombatantDisplays
@onready var player_slots: Control = $PlayerSlots
@onready var enemy_slots: Control = $EnemySlots
@onready var hud: Control = $BattleHUD

var actions_used: int = 0
var combat_result_reported: bool = false
var last_accounted_combat_time: float = 0.0
var audio_bridge: Node = null
var participant_hp_before_by_id: Dictionary = {}
var pending_player_action: CombatActionData = null
var targeting_valid_targets: Array[Combatant] = []
var player_leader: Combatant = null
var player_combatants: Array[Combatant] = []
var enemy_combatants: Array[Combatant] = []
var ai_player_combatants: Array[Combatant] = []
var enemy_instance_data: Array[Dictionary] = []
var combatant_display_entries: Array[Dictionary] = []
var _game_manager = null

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	_configure_encounter_from_game_manager()
	_setup_player_combatants()
	_setup_enemy_combatants()

	battle.player = player_leader
	battle.enemy = _primary_enemy()
	battle.configure_combatant_groups(player_combatants, enemy_combatants)
	battle.set_ai_controlled_combatants(ai_player_combatants)

	if hud.get_script() == null:
		hud.set_script(BattleHudScript)

	hud.call("setup", battle, player_leader, _primary_enemy(), battle.player_group, battle.enemy_group)
	_setup_combatant_displays()
	hud.connect("action_selected", Callable(self, "_choose_player_action"))
	hud.connect("speed_requested", Callable(self, "_on_speed_requested"))
	hud.connect("pause_requested", Callable(self, "_on_pause_requested"))

	_connect_battle_signals()
	_connect_group_combatant_signals(battle.player_group)
	_connect_group_combatant_signals(battle.enemy_group)
	_connect_combat_result_signals()
	_connect_run_signals()

	battle.start_battle()
	_capture_starting_participant_state()
	_setup_audio_bridge()
	_refresh_hud()

func _input(event: InputEvent) -> void:
	if _handle_targeting_input(event):
		return

	if not battle.waiting_for_player_input or _is_targeting():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		hud.call("choose_hotbar_keycode", event.keycode)

func _setup_player_combatants() -> void:
	player_combatants.clear()
	ai_player_combatants.clear()

	player_leader = _new_player_combatant("PlayerLeader")
	player_leader.profile = _selected_player_profile()
	player_leader.apply_profile()
	_apply_run_player_state()
	if player_leader.combatant_id.is_empty():
		player_leader.combatant_id = "combatant.player_leader"
	player_combatants.append(player_leader)

	#; Temporary group-combat test allies until real party members join combat.
	for index in range(TEMPORARY_PLAYER_AI_COPY_COUNT):
		var ally := _new_player_combatant("PlayerAlly%s" % (index + 1))
		ally.profile = player_leader.profile
		ally.apply_profile()
		ally.combatant_id = "temporary.player_ally.%s" % (index + 1)
		ally.display_name = "%s Ally %s" % [_player_profile_display_name(player_leader.profile), index + 1]
		player_combatants.append(ally)
		ai_player_combatants.append(ally)

func _setup_enemy_combatants() -> void:
	enemy_combatants.clear()
	if enemy_instance_data.is_empty():
		push_error("BattleScene cannot set up combat without validated enemy instances.")
		return

	for index in enemy_instance_data.size():
		var instance_data: Dictionary = enemy_instance_data[index]
		var active_enemy := _new_enemy_combatant("Enemy%s" % (index + 1))
		active_enemy.combatant_id = str(instance_data.get("instance_id", "enemy_%s" % (index + 1)))
		var enemy_profile := _profile_for_enemy_instance(instance_data)
		if enemy_profile == null:
			push_error("BattleScene cannot load enemy profile for instance %s." % instance_data)
			continue
		active_enemy.profile = enemy_profile
		active_enemy.apply_profile()
		_apply_enemy_instance_stats(active_enemy, instance_data)
		enemy_combatants.append(active_enemy)

func _apply_enemy_instance_stats(active_enemy: Combatant, instance_data: Dictionary) -> void:
	if active_enemy == null:
		return

	var enemy_level: int = int(instance_data.get("level", 0))
	var stat_seed: int = int(instance_data.get("stat_seed", active_enemy.name.hash()))
	var stats: Dictionary = CombatantStatAllocatorScript.allocate_enemy_stats(active_enemy.profile, battle.difficulty_profile, enemy_level, stat_seed)
	CombatantStatAllocatorScript.apply_stats_to_combatant(active_enemy, stats)
	if active_enemy.profile != null and enemy_level > 0:
		active_enemy.display_name = "%s Lv %s" % [active_enemy.profile.display_name, enemy_level]

func _new_player_combatant(node_name: String) -> Combatant:
	var script: Script = _player_combatant_script()
	var combatant := script.new() as Combatant
	if combatant == null:
		combatant = CombatantScript.new() as Combatant
	combatant.name = node_name
	combatants_root.add_child(combatant)
	return combatant

func _new_enemy_combatant(node_name: String) -> Combatant:
	var combatant := EnemyCombatantScript.new() as Combatant
	combatant.name = node_name
	combatants_root.add_child(combatant)
	return combatant

func _player_combatant_script() -> Script:
	var selected_character_id := ""
	if _game_manager != null:
		selected_character_id = _game_manager.get_selected_character_id()

	match selected_character_id:
		"Warrior", "":
			return WarriorCombatantScript
		_:
			return CombatantScript

func _selected_player_profile() -> CombatantProfile:
	if _game_manager != null:
		var profile: CombatantProfile = _game_manager.get_selected_character_profile() as CombatantProfile
		if profile != null:
			return profile

	return DEFAULT_PLAYER_PROFILE

func _player_profile_display_name(profile: CombatantProfile) -> String:
	if profile != null and not profile.display_name.is_empty():
		return profile.display_name

	return "Player"

func _setup_combatant_displays() -> void:
	combatant_display_entries.clear()

	for index in player_combatants.size():
		var display: CombatantDisplayScript = _new_combatant_display("PlayerDisplay%s" % (index + 1))
		var slot_id: StringName = PLAYER_SLOT_IDS[min(index, PLAYER_SLOT_IDS.size() - 1)]
		_setup_combatant_display(display, player_combatants[index], player_slots, slot_id, DEFAULT_PLAYER_SLOT_ID)

	for index in enemy_combatants.size():
		var display: CombatantDisplayScript = _new_combatant_display("EnemyCombatantDisplay%s" % (index + 1))
		var instance_data: Dictionary = enemy_instance_data[index] if index < enemy_instance_data.size() else {}
		var slot_id: StringName = ValueReaderScript.string_name_from_variant(instance_data.get("slot_id", &""))
		if String(slot_id).is_empty():
			slot_id = ENEMY_SLOT_IDS[min(index, ENEMY_SLOT_IDS.size() - 1)]
		_setup_combatant_display(display, enemy_combatants[index], enemy_slots, slot_id, DEFAULT_ENEMY_SLOT_ID)

func _new_combatant_display(display_name: String) -> CombatantDisplayScript:
	var display := CombatantDisplayScene.instantiate() as CombatantDisplayScript
	display.name = display_name
	combatant_displays_root.add_child(display)
	return display

func _setup_combatant_display(
	display: CombatantDisplayScript,
	combatant: Combatant,
	slot_parent: Control,
	slot_id: StringName,
	fallback_slot_id: StringName
) -> void:
	if display == null or combatant == null:
		return

	_apply_display_slot(display, slot_parent, slot_id, fallback_slot_id)
	display.setup(combatant)
	if not display.target_selected.is_connected(_on_target_display_selected):
		display.target_selected.connect(_on_target_display_selected)
	combatant_display_entries.append({
		"combatant": combatant,
		"display": display,
	})

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
	if _game_manager == null:
		return

	if not _game_manager.run_ended.is_connected(_on_run_ended):
		_game_manager.run_ended.connect(_on_run_ended)

func _setup_audio_bridge() -> void:
	audio_bridge = CombatAudioBridgeScript.new()
	audio_bridge.name = "CombatAudioBridge"
	add_child(audio_bridge)
	var encounter := CombatManager.get_current_combat_payload()
	audio_bridge.call("setup", battle, player_leader, _primary_enemy(), bool(encounter.get("is_boss", false)), battle.player_group, battle.enemy_group)

## Starts explicit player targeting or immediately queues auto-targeted actions.
func _choose_player_action(index: int) -> void:
	if _is_targeting() or not battle.waiting_for_player_input or battle.battle_over or player_leader == null or player_leader.hp <= 0:
		return
	if index < 0 or index >= player_leader.actions.size():
		return

	var action: CombatActionData = player_leader.actions[index]
	if not CombatTargetingScript.requires_manual_target(action):
		var was_waiting_for_input := battle.waiting_for_player_input
		battle.player_choose_action(action)
		if was_waiting_for_input and not battle.waiting_for_player_input:
			actions_used += 1
		_refresh_hud()
		return

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

	if elapsed_seconds <= 0.0 or combat_result_reported or _game_manager == null:
		return

	if not _game_manager.advance_run_time(elapsed_seconds):
		combat_result_reported = true

func _refresh_hud(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	hud.call("refresh")
	for entry in combatant_display_entries:
		var display: Control = entry.get("display", null) as Control
		if display != null and display.has_method("refresh"):
			display.call("refresh")

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

	var opponents: Array[Combatant] = battle.enemy_group.get_living_combatants() if battle.enemy_group != null else []
	var allies: Array[Combatant] = battle.player_group.get_living_combatants() if battle.player_group != null else []
	return CombatTargetingScript.manual_targets_for_action(action, player_leader, opponents, allies)

func _apply_targeting_display_states() -> void:
	for entry in combatant_display_entries:
		var display: Control = entry.get("display", null) as Control
		var combatant: Combatant = entry.get("combatant", null) as Combatant
		if display != null and display.has_method("set_targeting_state"):
			var can_target := combatant != null and targeting_valid_targets.has(combatant)
			display.call("set_targeting_state", can_target, can_target)

func _clear_targeting_display_states() -> void:
	for entry in combatant_display_entries:
		var display: Control = entry.get("display", null) as Control
		if display != null and display.has_method("clear_targeting_state"):
			display.call("clear_targeting_state")

func _configure_encounter_from_game_manager() -> void:
	if _game_manager == null:
		return

	var encounter := CombatManager.get_current_combat_payload()
	if encounter.is_empty():
		push_error("BattleScene cannot configure combat because CombatManager has no active payload.")
		return
	enemy_instance_data = _enemy_instances_for_encounter(encounter)
	battle.difficulty_profile = _game_manager.get_selected_difficulty_profile()

func _enemy_instances_for_encounter(encounter: Dictionary) -> Array[Dictionary]:
	var instances := _enemy_instances_from_variant(encounter.get("enemy_instances", []))
	if not instances.is_empty():
		for instance in instances:
			if not _is_valid_enemy_instance(instance):
				push_error("BattleScene received malformed enemy instance: %s." % instance)
				return []
		return instances

	push_error("BattleScene received a combat encounter without enemy_instances.")
	return instances

func _enemy_instances_from_variant(raw_instances: Variant) -> Array[Dictionary]:
	var instances: Array[Dictionary] = []
	if not (raw_instances is Array):
		return instances

	for raw_instance in raw_instances:
		if raw_instance is Dictionary:
			instances.append(raw_instance.duplicate(true))

	return instances

func _profile_for_enemy_instance(instance_data: Dictionary) -> CombatantProfile:
	var profile_path := str(instance_data.get("profile_path", "")).strip_edges()
	if not profile_path.is_empty():
		var loaded_profile := load(profile_path) as CombatantProfile
		if loaded_profile != null:
			return loaded_profile

	return null

func _is_valid_enemy_instance(instance_data: Dictionary) -> bool:
	if String(instance_data.get("instance_id", "")).strip_edges().is_empty():
		return false
	if String(instance_data.get("profile_path", "")).strip_edges().is_empty():
		return false
	if String(instance_data.get("slot_id", "")).strip_edges().is_empty():
		return false
	if not instance_data.has("level"):
		return false
	if not instance_data.has("stat_seed"):
		return false

	return true

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
	if player_leader == null or _game_manager == null:
		return

	var selected_combatant_id: String = str(_game_manager.get_selected_player_combatant_id())
	if not selected_combatant_id.strip_edges().is_empty():
		player_leader.combatant_id = selected_combatant_id
	_game_manager.apply_run_player_state_to_combatant(player_leader)
	var hp_snapshot: Dictionary = _game_manager.get_run_player_hp_snapshot()
	battle.player_starting_hp_override = int(hp_snapshot.get("current", player_leader.max_hp))
	battle.player_starting_max_hp_override = int(hp_snapshot.get("max", player_leader.max_hp))

func _on_enemy_group_defeated() -> void:
	_finish_combat(true)

func _on_player_group_defeated() -> void:
	_finish_combat(false)

func _on_run_ended(reason: String) -> void:
	if reason != RunData.END_REASON_TIMEOUT or combat_result_reported:
		return

	_cancel_targeting(false)
	combat_result_reported = true
	var result: Variant = _build_combat_result(false)
	result.end_reason = reason

	if _game_manager != null:
		CombatManager.complete_combat(result)
		_game_manager.emit_run_state()

func _finish_combat(victory: bool) -> void:
	if combat_result_reported:
		return

	_cancel_targeting(false)
	combat_result_reported = true
	var result: Variant = _build_combat_result(victory)
	result.end_reason = "" if victory else RunData.END_REASON_DEFEAT

	if _game_manager == null:
		return

	await get_tree().create_timer(1.0).timeout
	_game_manager.complete_combat(result)

func _build_combat_result(victory: bool) -> Variant:
	var encounter := CombatManager.get_current_combat_payload()
	var result: Variant = CombatResultScript.new()
	result.victory = victory
	result.node_id = int(encounter.get("node_id", -1))
	result.is_boss = bool(encounter.get("is_boss", false))
	result.winning_side_id = CombatResultScript.SIDE_ID_PLAYER if victory else CombatResultScript.SIDE_ID_ENEMY
	result.defeated_side_ids = _defeated_side_ids()
	result.participant_results = _participant_results(victory)
	result.damage_dealt = _group_hp_delta(battle.enemy_group)
	result.damage_taken = _group_hp_delta(battle.player_group)
	result.actions_used = actions_used
	result.time_elapsed = battle.current_time
	return result

func _capture_starting_participant_state() -> void:
	participant_hp_before_by_id.clear()
	_capture_group_starting_state(battle.player_group)
	_capture_group_starting_state(battle.enemy_group)

func _capture_group_starting_state(group: Variant) -> void:
	if group == null:
		return

	for combatant in group.combatants:
		var active_combatant := combatant as Combatant
		if active_combatant != null:
			participant_hp_before_by_id[_combatant_result_id(active_combatant)] = active_combatant.hp

func _participant_results(victory: bool) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append_array(_group_participant_results(battle.player_group, CombatResultScript.SIDE_ID_PLAYER, victory))
	results.append_array(_group_participant_results(battle.enemy_group, CombatResultScript.SIDE_ID_ENEMY, victory))
	return results

func _group_participant_results(group: Variant, side_id: String, victory: bool) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if group == null:
		return results

	for combatant in group.combatants:
		var active_combatant := combatant as Combatant
		if active_combatant != null:
			results.append(_participant_result(active_combatant, side_id, victory))
	return results

func _participant_result(combatant: Combatant, side_id: String, victory: bool) -> Dictionary:
	var combatant_id := _combatant_result_id(combatant)
	var hp_after := combatant.hp
	if victory and side_id == CombatResultScript.SIDE_ID_PLAYER and hp_after <= 0:
		hp_after = 1

	return {
		CombatResultScript.PARTICIPANT_COMBATANT_ID: combatant_id,
		CombatResultScript.PARTICIPANT_SIDE_ID: side_id,
		CombatResultScript.PARTICIPANT_NODE_NAME: str(combatant.name),
		CombatResultScript.PARTICIPANT_PROFILE_PATH: combatant.profile.resource_path if combatant.profile != null else "",
		CombatResultScript.PARTICIPANT_HP_BEFORE: int(participant_hp_before_by_id.get(combatant_id, combatant.max_hp)),
		CombatResultScript.PARTICIPANT_HP_AFTER: hp_after,
		CombatResultScript.PARTICIPANT_MAX_HP: combatant.max_hp,
		CombatResultScript.PARTICIPANT_DEFEATED: hp_after <= 0,
	}

func _defeated_side_ids() -> Array[String]:
	var defeated_side_ids: Array[String] = []
	if battle.is_player_group_defeated():
		defeated_side_ids.append(CombatResultScript.SIDE_ID_PLAYER)
	if battle.is_enemy_group_defeated():
		defeated_side_ids.append(CombatResultScript.SIDE_ID_ENEMY)
	return defeated_side_ids

func _group_hp_delta(group: Variant) -> int:
	var total_delta := 0
	if group != null:
		for combatant in group.combatants:
			var active_combatant := combatant as Combatant
			if active_combatant == null:
				continue
			var combatant_id := _combatant_result_id(active_combatant)
			var hp_before := int(participant_hp_before_by_id.get(combatant_id, active_combatant.max_hp))
			total_delta += max(hp_before - active_combatant.hp, 0)

	return total_delta

func _combatant_result_id(combatant: Combatant) -> String:
	if combatant == null:
		return ""
	if not combatant.combatant_id.strip_edges().is_empty():
		return combatant.combatant_id
	if not str(combatant.name).is_empty():
		return str(combatant.name)

	return str(combatant.get_instance_id())

func _primary_enemy() -> Combatant:
	if not enemy_combatants.is_empty():
		return enemy_combatants[0]

	return null
