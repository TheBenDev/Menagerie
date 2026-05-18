## Bridges combat events to SoundManager by playing action SFX and updating adaptive combat music states.
extends Node

var battle: BattleController = null
var player: Combatant = null
var enemy: Combatant = null
var player_group: CombatantGroup = null
var enemy_group: CombatantGroup = null
var is_boss: bool = false

var _last_hp_by_combatant: Dictionary = {}
var _last_block_by_combatant: Dictionary = {}

func setup(
	new_battle: BattleController,
	new_player: Combatant,
	new_enemy: Combatant,
	new_is_boss: bool,
	new_player_group: CombatantGroup = null,
	new_enemy_group: CombatantGroup = null
) -> void:
	battle = new_battle
	player = new_player
	enemy = new_enemy
	is_boss = new_is_boss
	player_group = new_player_group
	enemy_group = new_enemy_group

	_connect_battle_signals()
	_connect_group_combatant_signals(player_group, player)
	_connect_group_combatant_signals(enemy_group, enemy)
	_capture_group_snapshots(player_group, player)
	_capture_group_snapshots(enemy_group, enemy)
	_refresh_music_state()

func _connect_battle_signals() -> void:
	if battle == null:
		return

	if not battle.time_changed.is_connected(_on_battle_state_changed):
		battle.time_changed.connect(_on_battle_state_changed)
	if not battle.action_queue_changed.is_connected(_on_battle_state_changed):
		battle.action_queue_changed.connect(_on_battle_state_changed)
	if not battle.player_ready.is_connected(_on_battle_state_changed):
		battle.player_ready.connect(_on_battle_state_changed)

func _connect_combatant_signals(combatant: Combatant) -> void:
	if combatant == null:
		return

	if not combatant.action_started.is_connected(_on_action_started):
		combatant.action_started.connect(_on_action_started)
	if not combatant.action_resolved.is_connected(_on_action_resolved):
		combatant.action_resolved.connect(_on_action_resolved)
	if not combatant.hp_changed.is_connected(_on_hp_changed):
		combatant.hp_changed.connect(_on_hp_changed)
	if not combatant.block_changed.is_connected(_on_block_changed):
		combatant.block_changed.connect(_on_block_changed)
	if not combatant.died.is_connected(_on_died):
		combatant.died.connect(_on_died)

func _connect_group_combatant_signals(group: CombatantGroup, fallback_combatant: Combatant) -> void:
	var connected_any := false
	if group != null:
		for combatant in group.combatants:
			_connect_combatant_signals(combatant)
			connected_any = connected_any or combatant != null

	if not connected_any:
		_connect_combatant_signals(fallback_combatant)

func _capture_combatant_snapshot(combatant: Combatant) -> void:
	if combatant == null:
		return

	_last_hp_by_combatant[combatant.get_instance_id()] = combatant.hp
	_last_block_by_combatant[combatant.get_instance_id()] = combatant.block

func _capture_group_snapshots(group: CombatantGroup, fallback_combatant: Combatant) -> void:
	var captured_any := false
	if group != null:
		for combatant in group.combatants:
			_capture_combatant_snapshot(combatant)
			captured_any = captured_any or combatant != null

	if not captured_any:
		_capture_combatant_snapshot(fallback_combatant)

func _on_action_started(_combatant: Combatant, action: CombatActionData) -> void:
	_play_sfx(action.start_sfx_id, 2)
	_refresh_music_state()

func _on_action_resolved(_combatant: Combatant, action: CombatActionData) -> void:
	_play_sfx(action.resolve_sfx_id, 3)
	_refresh_music_state()

func _on_hp_changed(combatant: Combatant) -> void:
	var instance_id := combatant.get_instance_id()
	var previous_hp := int(_last_hp_by_combatant.get(instance_id, combatant.hp))
	if combatant.hp < previous_hp and combatant.hp > 0:
		_play_sfx(_profile_sfx_id(combatant, "hit_sfx_id"), 4)

	_last_hp_by_combatant[instance_id] = combatant.hp
	_refresh_music_state()

func _on_block_changed(combatant: Combatant) -> void:
	var instance_id := combatant.get_instance_id()
	var previous_block := int(_last_block_by_combatant.get(instance_id, combatant.block))
	if combatant.block < previous_block:
		_play_sfx(_profile_sfx_id(combatant, "block_sfx_id"), 4)

	_last_block_by_combatant[instance_id] = combatant.block
	_refresh_music_state()

func _on_died(combatant: Combatant) -> void:
	_play_sfx(_profile_sfx_id(combatant, "death_sfx_id"), 8)
	_refresh_music_state()

func _on_battle_state_changed(_arg: Variant = null) -> void:
	_refresh_music_state()

func _refresh_music_state() -> void:
	var music_director := _music_director()
	if music_director == null or not _has_music_pressure_sources():
		return

	var intensity := _combat_intensity()
	music_director.call("set_combat_music_pressure", intensity)

func _combat_intensity() -> float:
	var player_pressure: float = _group_hp_pressure(player_group, player)
	var enemy_pressure: float = _group_hp_pressure(enemy_group, enemy)
	var queue_pressure: float = min(float(_pending_action_count()) / 3.0, 1.0)
	var boss_pressure: float = 0.25 if is_boss else 0.0
	var intensity: float = max(player_pressure, enemy_pressure * 0.75, queue_pressure * 0.5, boss_pressure)
	return clamp(intensity, 0.0, 1.0)

func _pending_action_count() -> int:
	if battle == null:
		return 0

	var count := 0
	for entry in battle.action_queue:
		if entry != null and entry.has_method("is_pending") and entry.is_pending():
			count += 1

	return count

func _hp_percent(combatant: Combatant) -> float:
	if combatant == null or combatant.max_hp <= 0:
		return 0.0

	return clamp(float(combatant.hp) / float(combatant.max_hp), 0.0, 1.0)

func _has_music_pressure_sources() -> bool:
	return _has_group_or_fallback_combatant(player_group, player) \
		and _has_group_or_fallback_combatant(enemy_group, enemy)

func _has_group_or_fallback_combatant(group: CombatantGroup, fallback_combatant: Combatant) -> bool:
	if group != null:
		for combatant in group.combatants:
			if combatant != null:
				return true

	return fallback_combatant != null

func _group_hp_pressure(group: CombatantGroup, fallback_combatant: Combatant) -> float:
	var pressure := 0.0
	var saw_combatant := false
	if group != null:
		for combatant in group.combatants:
			if combatant == null:
				continue
			saw_combatant = true
			pressure = max(pressure, 1.0 - _hp_percent(combatant))

	if saw_combatant:
		return clamp(pressure, 0.0, 1.0)

	return clamp(1.0 - _hp_percent(fallback_combatant), 0.0, 1.0)

func _profile_sfx_id(combatant: Combatant, field_name: String) -> StringName:
	if combatant == null or combatant.profile == null:
		return &""

	match field_name:
		"hit_sfx_id":
			return combatant.profile.hit_sfx_id
		"block_sfx_id":
			return combatant.profile.block_sfx_id
		"death_sfx_id":
			return combatant.profile.death_sfx_id
		_:
			return &""

func _play_sfx(sfx_id: StringName, priority: int) -> void:
	var sound_manager := _sound_manager()
	if String(sfx_id).is_empty() or sound_manager == null:
		return

	sound_manager.call("play_sfx", sfx_id, {"priority": priority})

func _sound_manager() -> Node:
	return get_node_or_null("/root/SoundManager")

func _music_director() -> Node:
	return get_node_or_null("/root/MusicDirector")
