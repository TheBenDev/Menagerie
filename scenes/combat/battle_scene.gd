## Scene coordinator that wires combatants, HUD, audio, run data, and final combat result reporting.
extends Node

const CombatResultScript := preload("res://core/combat/combat_result.gd")
const BattleHudScript := preload("res://scenes/combat/ui/battle_hud.gd")
const CombatAudioBridgeScript := preload("res://core/audio/combat_audio_bridge.gd")

@onready var battle: BattleController = $BattleController
@onready var warrior: WarriorCombatant = $Warrior
@onready var enemy: EnemyCombatant = $Enemy
@onready var hud: Control = $BattleHUD

var actions_used: int = 0
var combat_result_reported: bool = false
var last_accounted_combat_time: float = 0.0
var audio_bridge: Node = null

func _ready() -> void:
	_configure_encounter_from_game_manager()
	warrior.apply_profile()
	enemy.apply_profile()
	_apply_boss_overrides()

	battle.player = warrior
	battle.enemy = enemy

	if hud.get_script() == null:
		hud.set_script(BattleHudScript)

	hud.call("setup", battle, warrior, enemy)
	hud.connect("action_selected", Callable(self, "_choose_warrior_action"))
	hud.connect("speed_requested", Callable(self, "_on_speed_requested"))
	hud.connect("pause_requested", Callable(self, "_on_pause_requested"))

	_connect_battle_signals()
	_connect_combatant_signals(warrior)
	_connect_combatant_signals(enemy)
	_connect_combat_result_signals()
	_connect_run_signals()
	_setup_audio_bridge()

	battle.start_battle()
	_refresh_hud()

func _input(event: InputEvent) -> void:
	if not battle.waiting_for_player_input:
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
	combatant.hp_changed.connect(_refresh_hud)
	combatant.block_changed.connect(_refresh_hud)
	combatant.statuses_changed.connect(_refresh_hud)
	combatant.action_started.connect(_refresh_hud)
	combatant.action_resolved.connect(_refresh_hud)
	combatant.died.connect(_refresh_hud)

	if combatant.has_signal("rage_changed"):
		combatant.connect("rage_changed", Callable(self, "_refresh_hud"))

func _connect_combat_result_signals() -> void:
	if not warrior.died.is_connected(_on_warrior_died):
		warrior.died.connect(_on_warrior_died)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)

func _connect_run_signals() -> void:
	if not _has_game_manager():
		return

	if not GameManager.run_ended.is_connected(_on_run_ended):
		GameManager.run_ended.connect(_on_run_ended)

func _setup_audio_bridge() -> void:
	audio_bridge = CombatAudioBridgeScript.new()
	audio_bridge.name = "CombatAudioBridge"
	add_child(audio_bridge)
	var encounter := GameManager.get_current_encounter() if _has_game_manager() else {}
	audio_bridge.call("setup", battle, warrior, enemy, bool(encounter.get("is_boss", false)))

func _choose_warrior_action(index: int) -> void:
	if index < 0 or index >= warrior.actions.size():
		return

	actions_used += 1
	battle.player_choose_action(warrior.actions[index])
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

func _action_index_for_key(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return int(keycode - KEY_1)

	return -1

func _configure_encounter_from_game_manager() -> void:
	if not _has_game_manager():
		return

	var encounter := GameManager.get_current_encounter()
	var enemy_profile_path: String = str(encounter.get("enemy_profile_path", ""))
	if not enemy_profile_path.is_empty():
		var enemy_profile := load(enemy_profile_path) as CombatantProfile
		if enemy_profile != null:
			enemy.profile = enemy_profile

	battle.difficulty_profile = GameManager.get_selected_difficulty_profile()

func _apply_boss_overrides() -> void:
	if not _has_game_manager() or not bool(GameManager.get_current_encounter().get("is_boss", false)):
		return

	enemy.display_name = "Training Boss"
	enemy.strength += 2
	enemy.vitality += 4

func _on_enemy_died(_combatant: Combatant) -> void:
	_finish_combat(true)

func _on_warrior_died(_combatant: Combatant) -> void:
	_finish_combat(false)

func _on_run_ended(reason: String) -> void:
	if reason != RunData.END_REASON_TIMEOUT or combat_result_reported:
		return

	var encounter := GameManager.get_current_encounter() if _has_game_manager() else {}
	combat_result_reported = true
	var result: Variant = CombatResultScript.new()
	result.victory = false
	result.node_id = int(encounter.get("node_id", -1))
	result.is_boss = bool(encounter.get("is_boss", false))
	result.enemy_defeated = enemy.hp <= 0
	result.player_defeated = warrior.hp <= 0
	result.damage_dealt = max(enemy.max_hp - enemy.hp, 0)
	result.damage_taken = max(warrior.max_hp - warrior.hp, 0)
	result.actions_used = actions_used
	result.time_elapsed = battle.current_time
	result.end_reason = reason

	if _has_game_manager() and GameManager.current_run_data != null:
		GameManager.current_run_data.register_combat_result(result)
		GameManager.emit_run_state()

func _finish_combat(victory: bool) -> void:
	if combat_result_reported:
		return

	combat_result_reported = true
	var encounter := GameManager.get_current_encounter() if _has_game_manager() else {}
	var result: Variant = CombatResultScript.new()
	result.victory = victory
	result.node_id = int(encounter.get("node_id", -1))
	result.is_boss = bool(encounter.get("is_boss", false))
	result.enemy_defeated = enemy.hp <= 0
	result.player_defeated = warrior.hp <= 0
	result.damage_dealt = max(enemy.max_hp - enemy.hp, 0)
	result.damage_taken = max(warrior.max_hp - warrior.hp, 0)
	result.actions_used = actions_used
	result.time_elapsed = battle.current_time
	result.end_reason = "" if victory else RunData.END_REASON_DEFEAT

	if not _has_game_manager():
		return

	if victory:
		var rewards: Dictionary = GameManager.calculate_rewards_for_profile(enemy.profile, result.is_boss)
		result.memories_awarded = int(rewards.get("memories_awarded", 0))
		result.gold_awarded = int(rewards.get("gold_awarded", 0))

	await get_tree().create_timer(1.0).timeout
	GameManager.complete_combat(result)

func _has_game_manager() -> bool:
	return get_node_or_null("/root/GameManager") != null
