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
const CombatEffectLibraryScript := preload("res://core/combat/actions/combat_effect_library.gd")
const ActionCostServiceScript := preload("res://core/combat/actions/action_cost_service.gd")
const CombatPayloadValidatorScript := preload("res://core/combat/combat_payload_validator.gd")
const QueuedActionScript := preload("res://core/combat/actions/queued_action.gd")
const StatusDataScript := preload("res://core/statuses/status_data.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const HotbarSlotSchemaScript := preload("res://core/combat/classes/hotbar_slot_schema.gd")

const DEFAULT_PLAYER_SLOT_ID := &"PlayerSlot1"
const DEFAULT_ENEMY_SLOT_ID := &"EnemySlot1"
const PLAYER_SLOT_IDS := [&"PlayerSlot1", &"PlayerSlot2", &"PlayerSlot3"]
const ENEMY_SLOT_IDS := [&"EnemySlot1", &"EnemySlot2", &"EnemySlot3", &"EnemySlot4"]

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
var pending_player_slot_id: StringName = &""
var pending_player_actor_id: String = ""
var targeting_valid_targets: Array[Combatant] = []
var player_leader: Combatant = null
var player_combatants: Array[Combatant] = []
var enemy_combatants: Array[Combatant] = []
var ai_player_combatants: Array[Combatant] = []
var actor_owner_peer_ids: Dictionary = {}
var enemy_instance_data: Array[Dictionary] = []
var combatant_display_entries: Array[Dictionary] = []
var _game_manager = null
var combat_setup_failed: bool = false

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	if not NetworkManager.authoritative_snapshot_received.is_connected(_on_authoritative_snapshot_received):
		NetworkManager.authoritative_snapshot_received.connect(_on_authoritative_snapshot_received)
	if NetworkManager.is_authority():
		CombatManager.register_battle_scene(self)
	combat_setup_failed = false
	_configure_encounter_from_game_manager()
	if not combat_setup_failed:
		_setup_player_combatants()
	if not combat_setup_failed:
		_setup_enemy_combatants()

	if combat_setup_failed:
		push_error("BattleScene combat setup failed; aborting battle initialization.")
		return
	if player_combatants.is_empty() or player_leader == null:
		push_error("BattleScene cannot initialize combat without player combatants.")
		return
	if enemy_combatants == null or enemy_combatants.is_empty():
		push_error("BattleScene cannot initialize combat without enemy combatants.")
		return

	battle.player = player_leader
	battle.enemy = _primary_enemy()
	battle.configure_combatant_groups(player_combatants, enemy_combatants)
	battle.set_ai_controlled_combatants(ai_player_combatants)

	if hud.get_script() == null:
		hud.set_script(BattleHudScript)

	hud.call("setup", battle, player_leader, _primary_enemy(), battle.player_group, battle.enemy_group)
	_setup_combatant_displays()
	hud.connect("hotbar_slot_used", Callable(self, "_choose_player_slot"))
	hud.connect("speed_requested", Callable(self, "_on_speed_requested"))
	hud.connect("pause_requested", Callable(self, "_on_pause_requested"))

	_connect_battle_signals()
	_connect_group_combatant_signals(battle.player_group)
	_connect_group_combatant_signals(battle.enemy_group)
	_connect_combat_result_signals()
	_connect_run_signals()

	if not NetworkManager.is_client():
		battle.start_battle()
		_apply_party_hp_to_player_combatants()
	_capture_starting_participant_state()
	_setup_audio_bridge()
	if NetworkManager.is_client():
		_apply_combat_snapshot(NetworkManager.last_authoritative_snapshot.get("combat", {}))
	_refresh_hud()

func _exit_tree() -> void:
	if CombatManager != null:
		CombatManager.unregister_battle_scene(self)

func _input(event: InputEvent) -> void:
	if _handle_targeting_input(event):
		return

	if not battle.waiting_for_player_input or _is_targeting():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		hud.call("choose_hotbar_keycode", event.keycode)

func _setup_player_combatants() -> void:
	player_leader = null
	player_combatants.clear()
	ai_player_combatants.clear()
	actor_owner_peer_ids.clear()

	var party_snapshot: Dictionary = _party_snapshot_for_view()
	var members: Dictionary = party_snapshot.get("members", {})
	var active_member_ids: Array = party_snapshot.get("active_member_ids", [])
	for index in active_member_ids.size():
		var member_id := str(active_member_ids[index])
		var member_snapshot: Dictionary = members.get(member_id, {})
		if member_snapshot.is_empty():
			_fail_combat_setup("Combat setup missing party member snapshot for %s." % member_id)
			continue
		var character_id := str(member_snapshot.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			_fail_combat_setup("Combat setup missing character_id for party member %s." % member_id)
			continue
		if not PartyManager.has_character(character_id):
			_fail_combat_setup("Combat setup received unknown character_id %s for party member %s." % [character_id, member_id])
			continue
		var profile_path := str(member_snapshot.get("profile_path", "")).strip_edges()
		if profile_path.is_empty():
			_fail_combat_setup("Combat setup missing profile_path for party member %s (%s)." % [member_id, character_id])
			continue
		var registered_profile_path := PartyManager.get_character_profile_path(character_id)
		if profile_path != registered_profile_path:
			_fail_combat_setup("Combat setup profile path mismatch for %s: snapshot=%s registry=%s." % [character_id, profile_path, registered_profile_path])
			continue
		var profile := load(profile_path) as CombatantProfile
		if profile == null:
			_fail_combat_setup("Combat setup could not load CombatantProfile for party member %s from %s." % [member_id, profile_path])
			continue
		var active_player := _new_combatant("Player%s" % (index + 1), profile)
		if not active_player.profile_configuration_valid:
			_fail_combat_setup("Combat setup aborted invalid profile configuration for party member %s from %s." % [member_id, profile_path])
			active_player.queue_free()
			continue
		active_player.combatant_id = str(member_snapshot.get("combatant_id", "combatant.player_%s" % (index + 1)))
		active_player.display_name = _player_profile_display_name(active_player.profile)
		_game_manager.apply_run_player_state_to_combatant(active_player, StringName(member_id))
		var class_state_snapshot: Dictionary = member_snapshot.get("class_state", {})
		if not class_state_snapshot.is_empty() and active_player.has_method("apply_class_state_snapshot"):
			active_player.call("apply_class_state_snapshot", class_state_snapshot)
		var owner_peer_id := int(member_snapshot.get("owner_peer_id", 1))
		actor_owner_peer_ids[active_player.combatant_id] = owner_peer_id
		player_combatants.append(active_player)
		if player_leader == null or owner_peer_id == NetworkManager.local_peer_id():
			player_leader = active_player

	if player_combatants.is_empty():
		_fail_combat_setup("BattleScene cannot initialize combat without player party members.")

func _setup_enemy_combatants() -> void:
	enemy_combatants.clear()
	if enemy_instance_data.is_empty():
		_fail_combat_setup("BattleScene cannot set up combat without validated enemy instances.")
		return

	for index in enemy_instance_data.size():
		var instance_data: Dictionary = enemy_instance_data[index]
		var enemy_profile := _profile_for_enemy_instance(instance_data)
		if enemy_profile == null:
			_fail_combat_setup("BattleScene cannot load enemy profile for instance %s." % instance_data)
			continue
		var active_enemy := _new_combatant("Enemy%s" % (index + 1), enemy_profile)
		active_enemy.combatant_id = str(instance_data.get("instance_id", "enemy_%s" % (index + 1)))
		if not active_enemy.profile_configuration_valid:
			_fail_combat_setup("BattleScene aborted invalid enemy profile configuration for instance %s." % instance_data)
			active_enemy.queue_free()
			continue
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

func _new_combatant(node_name: String, combatant_profile: CombatantProfile) -> Combatant:
	var combatant := CombatantScript.new() as Combatant
	combatant.name = node_name
	combatant.profile = combatant_profile
	combatants_root.add_child(combatant)
	return combatant

func _player_profile_display_name(profile: CombatantProfile) -> String:
	if profile != null and not profile.display_name.is_empty():
		return profile.display_name

	return "Player"

func _fail_combat_setup(message: String) -> void:
	combat_setup_failed = true
	push_error(message)

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
	_bind_combatant_display_hover(display)
	if not display.target_selected.is_connected(_on_target_display_selected):
		display.target_selected.connect(_on_target_display_selected)
	combatant_display_entries.append({
		"combatant": combatant,
		"display": display,
	})

func _bind_combatant_display_hover(display: Control) -> void:
	if display == null or hud == null:
		return

	if display.has_method("set_hover_tooltip_layer") and hud.has_method("get_hover_tooltip_layer"):
		display.call("set_hover_tooltip_layer", hud.call("get_hover_tooltip_layer"))
	elif hud.has_method("bind_hover_source"):
		hud.call("bind_hover_source", display)

func _connect_battle_signals() -> void:
	battle.time_changed.connect(_refresh_hud)
	battle.time_changed.connect(_on_battle_time_changed)
	battle.player_ready.connect(_refresh_hud)
	battle.battle_log.connect(_refresh_hud)
	battle.time_scale_changed.connect(_refresh_hud)
	battle.pause_changed.connect(_refresh_hud)
	battle.action_queue_changed.connect(_refresh_hud)
	battle.player_ready.connect(_broadcast_combat_snapshot_deferred)
	battle.action_queue_changed.connect(_broadcast_combat_snapshot_deferred)

func _connect_combatant_signals(combatant: Combatant) -> void:
	if combatant == null:
		return

	combatant.hp_changed.connect(_refresh_hud)
	combatant.block_changed.connect(_refresh_hud)
	combatant.statuses_changed.connect(_refresh_hud)
	combatant.action_started.connect(_refresh_hud)
	combatant.action_resolved.connect(_refresh_hud)
	combatant.died.connect(_refresh_hud)
	combatant.hp_changed.connect(_broadcast_combat_snapshot_deferred)
	combatant.block_changed.connect(_broadcast_combat_snapshot_deferred)
	combatant.statuses_changed.connect(_broadcast_combat_snapshot_deferred)
	combatant.action_started.connect(_broadcast_combat_snapshot_deferred)
	combatant.action_resolved.connect(_broadcast_combat_snapshot_deferred)
	combatant.died.connect(_broadcast_combat_snapshot_deferred)

	if combatant.has_signal("class_resource_changed"):
		combatant.connect("class_resource_changed", Callable(self, "_refresh_hud"))
		combatant.connect("class_resource_changed", Callable(self, "_broadcast_combat_snapshot_deferred"))
	if combatant.has_signal("stance_changed"):
		combatant.connect("stance_changed", Callable(self, "_refresh_hud"))
		combatant.connect("stance_changed", Callable(self, "_broadcast_combat_snapshot_deferred"))

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

## Starts explicit player targeting or immediately queues auto-targeted slot actions.
func _choose_player_slot(slot_id: StringName, _slot_entry: Dictionary = {}) -> void:
	var actor := _local_ready_actor()
	if _is_targeting() or not battle.waiting_for_player_input or battle.battle_over or actor == null or actor.hp <= 0:
		return
	if slot_id == &"":
		return

	var action: CombatActionData = _action_for_actor_slot(actor, slot_id)
	if action == null:
		push_error("No action resolved for actor %s slot %s." % [_combatant_result_id(actor), slot_id])
		return
	if not CombatTargetingScript.requires_manual_target(action):
		NetworkManager.request_combat_action({
			"actor_id": _combatant_result_id(actor),
			"slot_id": String(slot_id),
			"target_ids": [],
		})
		_refresh_hud()
		return

	var valid_targets := _valid_player_targets_for_action(actor, action)
	if valid_targets.is_empty():
		return

	pending_player_action = action
	pending_player_slot_id = slot_id
	pending_player_actor_id = _combatant_result_id(actor)
	targeting_valid_targets = valid_targets
	hud.call("set_targeting_active", true)
	_apply_targeting_display_states()
	_refresh_hud()

func _on_speed_requested() -> void:
	battle.cycle_time_scale()

func _on_pause_requested() -> void:
	battle.toggle_pause()

func server_request_combat_action(sender_peer_id: int, payload: Dictionary) -> Dictionary:
	if not NetworkManager.is_authority():
		return {"accepted": false, "reason": "not_authority"}
	if battle == null or battle.battle_over:
		return {"accepted": false, "reason": "combat_not_accepting_actions"}
	var actor_id := str(payload.get("actor_id", "")).strip_edges()
	if actor_id.is_empty():
		return {"accepted": false, "reason": "missing_actor_id"}
	var actor := _combatant_for_id(actor_id)
	if actor == null:
		return {"accepted": false, "reason": "missing_actor"}
	if int(actor_owner_peer_ids.get(actor_id, -1)) != sender_peer_id:
		return {"accepted": false, "reason": "sender_does_not_own_actor"}
	if not battle.is_waiting_for_actor(actor_id):
		return {"accepted": false, "reason": "actor_not_waiting_for_input"}
	var slot_id := StringName(str(payload.get("slot_id", "")).strip_edges())
	if slot_id == &"":
		return {"accepted": false, "reason": "missing_slot_id"}
	var slot_entry := _slot_entry_for_actor(actor, slot_id)
	var slot_error := _slot_entry_error(slot_entry)
	if not slot_error.is_empty():
		return {"accepted": false, "reason": slot_error}
	var action: CombatActionData = _action_for_actor_slot(actor, slot_id)
	if action == null:
		return {"accepted": false, "reason": "invalid_slot_action"}
	var cost_error := ActionCostServiceScript.usability_error(actor, action)
	if not cost_error.is_empty():
		return {"accepted": false, "reason": cost_error}
	var explicit_targets := _combatants_for_ids(payload.get("target_ids", []))
	if CombatTargetingScript.requires_manual_target(action) and explicit_targets.is_empty():
		return {"accepted": false, "reason": "missing_manual_targets"}
	var resolved_targets := _resolved_targets_for_player_action(actor, action, explicit_targets)
	if resolved_targets.is_empty():
		return {"accepted": false, "reason": "no_valid_targets"}
	var start_cost_error := ActionCostServiceScript.spend_start_costs(actor, action)
	if not start_cost_error.is_empty():
		return {"accepted": false, "reason": start_cost_error}

	battle.player_choose_action_for_actor(actor, action, explicit_targets)
	if actor.has_method("on_hotbar_action_queued"):
		actor.call("on_hotbar_action_queued", slot_id)
	actions_used += 1
	_refresh_hud()
	return {"accepted": true, "reason": "combat_action_accepted"}

func get_combat_snapshot() -> Dictionary:
	return {
		"current_time": float(battle.current_time) if battle != null else 0.0,
		"battle_over": bool(battle.battle_over) if battle != null else false,
		"waiting_actor_ids": battle.waiting_for_actor_ids.duplicate() if battle != null else [],
		"actor_owner_peer_ids": actor_owner_peer_ids.duplicate(),
		"players": _combatant_snapshots(player_combatants, "player"),
		"enemies": _combatant_snapshots(enemy_combatants, "enemy"),
		"action_queue": _action_queue_snapshot(),
		"actions_used": actions_used,
	}

func _on_authoritative_snapshot_received(snapshot: Dictionary) -> void:
	if not NetworkManager.is_client():
		return
	if snapshot.has("combat"):
		_apply_combat_snapshot(snapshot.get("combat", {}))

func _apply_combat_snapshot(combat_snapshot: Dictionary) -> void:
	var runtime_snapshot: Dictionary = combat_snapshot.get("runtime", {})
	if runtime_snapshot.is_empty() or battle == null:
		return
	actor_owner_peer_ids = runtime_snapshot.get("actor_owner_peer_ids", {}).duplicate()
	battle.waiting_for_actor_ids.clear()
	for raw_actor_id in runtime_snapshot.get("waiting_actor_ids", []):
		battle.waiting_for_actor_ids.append(str(raw_actor_id))
	battle.waiting_for_player_input = not battle.waiting_for_actor_ids.is_empty()
	battle.battle_over = bool(runtime_snapshot.get("battle_over", battle.battle_over))
	battle.current_time = float(runtime_snapshot.get("current_time", battle.current_time))
	_apply_combatant_snapshots(runtime_snapshot.get("players", []))
	_apply_combatant_snapshots(runtime_snapshot.get("enemies", []))
	_apply_action_queue_snapshot(runtime_snapshot.get("action_queue", []))
	_refresh_hud()

func _apply_combatant_snapshots(raw_snapshots: Variant) -> void:
	if not (raw_snapshots is Array):
		return
	for raw_snapshot in raw_snapshots:
		if not (raw_snapshot is Dictionary):
			continue
		var snapshot: Dictionary = raw_snapshot
		var combatant := _combatant_for_id(str(snapshot.get("combatant_id", "")))
		if combatant == null:
			continue
		combatant.max_hp = max(int(snapshot.get("max_hp", combatant.max_hp)), 1)
		combatant.hp = clamp(int(snapshot.get("hp", combatant.hp)), 0, combatant.max_hp)
		combatant.block = max(int(snapshot.get("block", combatant.block)), 0)
		var class_resources_snapshot: Dictionary = snapshot.get("class_resources", {})
		if not class_resources_snapshot.is_empty() and combatant.has_method("apply_class_resources_snapshot"):
			combatant.call("apply_class_resources_snapshot", class_resources_snapshot)
		var class_state_snapshot: Dictionary = snapshot.get("class_state", {})
		if not class_state_snapshot.is_empty() and combatant.has_method("apply_class_state_snapshot"):
			combatant.call("apply_class_state_snapshot", class_state_snapshot)
		combatant.is_busy = bool(snapshot.get("is_busy", combatant.is_busy))
		combatant.action_finish_time = float(snapshot.get("action_finish_time", combatant.action_finish_time))
		combatant.display_name = str(snapshot.get("display_name", combatant.display_name))
		_apply_status_snapshots(combatant, snapshot.get("statuses", []))

func _apply_status_snapshots(combatant: Combatant, raw_statuses: Variant) -> void:
	if combatant == null or not (raw_statuses is Array):
		return

	combatant.statuses.clear()
	for raw_status in raw_statuses:
		if not (raw_status is Dictionary):
			continue
		var status_snapshot: Dictionary = raw_status
		var status_id := str(status_snapshot.get("status_id", "")).strip_edges()
		var remaining_seconds := float(status_snapshot.get("remaining_seconds", 0.0))
		if status_id.is_empty() or remaining_seconds <= 0.0:
			continue

		combatant.statuses[status_id] = {
			"data": _status_data_from_snapshot(status_snapshot),
			"remaining_seconds": remaining_seconds,
		}

	combatant.statuses_changed.emit(combatant)

func _status_data_from_snapshot(status_snapshot: Dictionary) -> Resource:
	var status_id := str(status_snapshot.get("status_id", "")).strip_edges()
	var status_path := str(status_snapshot.get("status_path", "")).strip_edges()
	if status_path.is_empty() and not status_id.is_empty():
		status_path = CombatEffectLibraryScript.status_path_for_id(StringName(status_id))

	var status_data := load(status_path) as Resource if not status_path.is_empty() else null
	if status_data != null:
		return status_data

	var fallback_status: Resource = StatusDataScript.new()
	fallback_status.set("id", status_id)
	fallback_status.set("display_name", str(status_snapshot.get("display_name", status_id.capitalize())))
	fallback_status.set("description", str(status_snapshot.get("description", "")))
	fallback_status.set("icon_atlas_coords", _vector2i_from_snapshot(status_snapshot.get("icon_atlas_coords", {}), Vector2i(-1, -1)))
	fallback_status.set("icon_atlas_cell_size", _vector2i_from_snapshot(status_snapshot.get("icon_atlas_cell_size", {}), Vector2i(200, 200)))
	return fallback_status

func _apply_action_queue_snapshot(raw_snapshots: Variant) -> void:
	if battle == null or not (raw_snapshots is Array):
		return

	battle.action_queue.clear()
	for raw_snapshot in raw_snapshots:
		if not (raw_snapshot is Dictionary):
			continue
		var snapshot: Dictionary = raw_snapshot
		var actor := _combatant_for_id(str(snapshot.get("actor_id", "")))
		if actor == null:
			continue
		var action := _action_for_actor_snapshot(actor, snapshot)
		if action == null:
			continue

		var entry: QueuedAction = QueuedActionScript.new(
			int(snapshot.get("queue_id", 0)),
			actor,
			action,
			float(snapshot.get("resolve_time", 0.0))
		)
		entry.status = str(snapshot.get("status", QueuedAction.STATUS_PENDING))
		entry.resolved_time = float(snapshot.get("resolved_time", -1.0))
		entry.resolution_order = int(snapshot.get("resolution_order", -1))
		battle.action_queue.append(entry)

	battle.action_queue_changed.emit()

func _action_for_actor_snapshot(actor: Combatant, snapshot: Dictionary) -> CombatActionData:
	if actor == null:
		return null

	var action_id := str(snapshot.get("action_id", "")).strip_edges()
	var action_name := str(snapshot.get("action_name", "")).strip_edges()
	if not action_id.is_empty() and actor.has_method("get_action_by_id"):
		var resolved_action := actor.call("get_action_by_id", action_id) as CombatActionData
		if resolved_action != null:
			return resolved_action
	for action in actor.actions:
		var combat_action := action as CombatActionData
		if combat_action == null:
			continue
		if not action_id.is_empty() and str(combat_action.id) == action_id:
			return combat_action
		if action_id.is_empty() and not action_name.is_empty() and combat_action.display_name == action_name:
			return combat_action

	return null

func _local_ready_actor() -> Combatant:
	if battle == null:
		return null
	for actor_id in battle.waiting_for_actor_ids:
		if int(actor_owner_peer_ids.get(actor_id, -1)) != NetworkManager.local_peer_id():
			continue
		var actor := _combatant_for_id(actor_id)
		if actor != null:
			return actor
	return null

func _combatant_for_id(combatant_id: String) -> Combatant:
	for combatant in player_combatants:
		if _combatant_result_id(combatant) == combatant_id:
			return combatant
	for combatant in enemy_combatants:
		if _combatant_result_id(combatant) == combatant_id:
			return combatant
	return null

func _combatants_for_ids(raw_ids: Variant) -> Array[Combatant]:
	var combatants: Array[Combatant] = []
	if not (raw_ids is Array):
		return combatants
	for raw_id in raw_ids:
		var combatant := _combatant_for_id(str(raw_id))
		if combatant != null and combatant.hp > 0:
			combatants.append(combatant)
	return combatants

func _combatant_snapshots(combatants: Array[Combatant], side_id: String) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for combatant in combatants:
		if combatant != null:
			snapshots.append({
				"combatant_id": _combatant_result_id(combatant),
				"side_id": side_id,
				"display_name": combatant.display_name,
				"profile_path": combatant.profile.resource_path if combatant.profile != null else "",
				"owner_peer_id": int(actor_owner_peer_ids.get(_combatant_result_id(combatant), 0)),
				"hp": int(combatant.hp),
				"max_hp": int(combatant.max_hp),
				"block": int(combatant.block),
				"class_resources": combatant.call("get_class_resources_snapshot") if combatant.has_method("get_class_resources_snapshot") else {},
				"class_state": combatant.call("get_class_state_snapshot") if combatant.has_method("get_class_state_snapshot") else {},
				"is_busy": bool(combatant.is_busy),
				"action_finish_time": float(combatant.action_finish_time),
				"statuses": _status_snapshots(combatant),
			})
	return snapshots

func _status_snapshots(combatant: Combatant) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if combatant == null:
		return snapshots
	for status_id in combatant.statuses.keys():
		var status_state: Dictionary = combatant.statuses.get(status_id, {})
		var status_data: Resource = status_state.get("data", null) as Resource
		snapshots.append({
			"status_id": str(status_id),
			"display_name": str(status_data.get("display_name")) if status_data != null else str(status_id),
			"description": str(status_data.get("description")) if status_data != null else "",
			"status_path": str(status_data.resource_path) if status_data != null else "",
			"icon_atlas_coords": _vector2i_snapshot(status_data.get("icon_atlas_coords")) if status_data != null else _vector2i_snapshot(Vector2i(-1, -1)),
			"icon_atlas_cell_size": _vector2i_snapshot(status_data.get("icon_atlas_cell_size")) if status_data != null else _vector2i_snapshot(Vector2i(200, 200)),
			"remaining_seconds": float(status_state.get("remaining_seconds", 0.0)),
		})
	return snapshots

func _vector2i_snapshot(value: Variant) -> Dictionary:
	var vector := _vector2i_from_snapshot(value, Vector2i.ZERO)
	return {
		"x": int(vector.x),
		"y": int(vector.y),
	}

func _vector2i_from_snapshot(value: Variant, default_value: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", default_value.x)), int(value.get("y", default_value.y)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))

	return default_value

func _action_queue_snapshot() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if battle == null:
		return snapshots
	for entry in battle.action_queue:
		if entry == null:
			continue
		snapshots.append({
			"queue_id": int(entry.id),
			"actor_id": _combatant_result_id(entry.actor),
			"action_id": str(entry.action.id) if entry.action != null else "",
			"action_name": str(entry.action.display_name) if entry.action != null else "",
			"resolve_time": float(entry.resolve_time),
			"status": str(entry.status),
			"resolved_time": float(entry.resolved_time),
			"resolution_order": int(entry.resolution_order),
		})
	return snapshots

func _party_snapshot_for_view() -> Dictionary:
	if NetworkManager.is_client() and not NetworkManager.last_authoritative_snapshot.is_empty():
		var party_snapshot: Dictionary = NetworkManager.last_authoritative_snapshot.get("party", {})
		if not party_snapshot.is_empty():
			return party_snapshot
	return _game_manager.get_party_snapshot() if _game_manager != null else {}

func _apply_party_hp_to_player_combatants() -> void:
	var party_snapshot: Dictionary = _party_snapshot_for_view()
	var members: Dictionary = party_snapshot.get("members", {})
	for member_snapshot in members.values():
		if not (member_snapshot is Dictionary):
			continue
		var member: Dictionary = member_snapshot
		var combatant := _combatant_for_id(str(member.get("combatant_id", "")))
		if combatant == null:
			continue
		var hp_snapshot: Dictionary = member.get("hp", {})
		combatant.max_hp = max(int(hp_snapshot.get("max", combatant.max_hp)), 1)
		combatant.hp = clamp(int(hp_snapshot.get("current", combatant.hp)), 0, combatant.max_hp)

func _on_battle_time_changed(current_time: float) -> void:
	if NetworkManager.is_client():
		return
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

func _broadcast_combat_snapshot_deferred(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	if NetworkManager.is_authority():
		NetworkManager.call_deferred("broadcast_run_snapshot", "combat_update")

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

	var actor_id := pending_player_actor_id
	var slot_id := pending_player_slot_id
	var target_ids: Array[String] = [_combatant_result_id(selected_target)]
	_cancel_targeting(false)

	NetworkManager.request_combat_action({
		"actor_id": actor_id,
		"slot_id": String(slot_id),
		"target_ids": target_ids,
	})
	_refresh_hud()

func _cancel_targeting(refresh_after_cancel: bool = true) -> void:
	if not _is_targeting() and targeting_valid_targets.is_empty():
		return

	pending_player_action = null
	pending_player_slot_id = &""
	pending_player_actor_id = ""
	targeting_valid_targets.clear()
	_clear_targeting_display_states()
	hud.call("set_targeting_active", false)
	if refresh_after_cancel:
		_refresh_hud()

func _valid_player_targets_for_action(actor: Combatant, action: CombatActionData) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	if battle == null or actor == null or action == null:
		return targets

	var opponents: Array[Combatant] = battle.enemy_group.get_living_combatants() if battle.enemy_group != null else []
	var allies: Array[Combatant] = battle.player_group.get_living_combatants() if battle.player_group != null else []
	return CombatTargetingScript.manual_targets_for_action(action, actor, opponents, allies)

func _resolved_targets_for_player_action(actor: Combatant, action: CombatActionData, explicit_targets: Array[Combatant]) -> Array[Combatant]:
	if battle == null or actor == null or action == null:
		return []
	var opponents: Array[Combatant] = battle.enemy_group.get_living_combatants() if battle.enemy_group != null else []
	var allies: Array[Combatant] = battle.player_group.get_living_combatants() if battle.player_group != null else []
	return CombatTargetingScript.targets_for_action(action, actor, opponents, allies, explicit_targets)

func _action_for_actor_slot(actor: Combatant, slot_id: StringName) -> CombatActionData:
	if actor == null or slot_id == &"":
		return null
	if not actor.has_method("resolve_hotbar_action"):
		push_error("Actor %s cannot resolve hotbar slot %s." % [_combatant_result_id(actor), slot_id])
		return null
	var action := actor.call("resolve_hotbar_action", slot_id) as CombatActionData
	if action == null:
		return null
	for registered_action in actor.actions:
		if registered_action == action:
			return action
		if registered_action != null and registered_action.id == action.id:
			return registered_action
	push_error("Actor %s resolved unregistered hotbar action %s." % [_combatant_result_id(actor), action.id])
	return null

func _slot_entry_for_actor(actor: Combatant, slot_id: StringName) -> Dictionary:
	if actor == null or slot_id == &"":
		return {}
	if not actor.has_method("get_hotbar_slot_entry"):
		push_error("Actor %s cannot provide hotbar slot %s." % [_combatant_result_id(actor), slot_id])
		return {}
	var entry_value: Variant = actor.call("get_hotbar_slot_entry", slot_id)
	return entry_value if entry_value is Dictionary else {}

func _slot_entry_error(slot_entry: Dictionary) -> String:
	if slot_entry.is_empty():
		return "invalid_slot"
	var kind := HotbarSlotSchemaScript.slot_kind(slot_entry)
	match kind:
		&"action":
			if not HotbarSlotSchemaScript.is_selectable(slot_entry):
				return "slot_disabled"
			return ""
		&"locked":
			return "slot_locked"
		&"disabled":
			return "slot_disabled"
		&"empty":
			return "slot_empty"
		_:
			return "invalid_slot_kind"

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

	var encounter := _combat_payload_for_view()
	if encounter.is_empty():
		_fail_combat_setup("BattleScene cannot configure combat because CombatManager has no active payload.")
		return
	MusicDirector.on_combat_started({"is_boss": bool(encounter.get("is_boss", false))})
	enemy_instance_data = _enemy_instances_for_encounter(encounter)
	battle.difficulty_profile = _game_manager.get_selected_difficulty_profile()

func _combat_payload_for_view() -> Dictionary:
	if NetworkManager.is_client() and not NetworkManager.last_authoritative_snapshot.is_empty():
		var combat_snapshot: Dictionary = NetworkManager.last_authoritative_snapshot.get("combat", {})
		var payload: Dictionary = combat_snapshot.get("payload", {})
		if not payload.is_empty():
			return payload
	return CombatManager.get_current_combat_payload()

func _enemy_instances_for_encounter(encounter: Dictionary) -> Array[Dictionary]:
	var instances := _enemy_instances_from_variant(encounter.get("enemy_instances", []))
	if not instances.is_empty():
		for instance in instances:
			var instance_error := CombatPayloadValidatorScript.enemy_instance_error(instance)
			if not instance_error.is_empty():
				_fail_combat_setup("BattleScene received malformed enemy instance (%s): %s." % [instance_error, instance])
				return []
		return instances

	_fail_combat_setup("BattleScene received a combat encounter without enemy_instances.")
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
	if profile_path.is_empty():
		_fail_combat_setup("Enemy instance is missing profile_path: %s." % instance_data)
		return null

	var loaded_profile := load(profile_path) as CombatantProfile
	if loaded_profile == null:
		_fail_combat_setup("Enemy profile path did not load a CombatantProfile: %s." % profile_path)
		return null

	return loaded_profile

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
	if NetworkManager.is_client():
		push_error("Clients cannot finish authoritative combat.")
		return
	if combat_result_reported:
		return

	_cancel_targeting(false)
	combat_result_reported = true
	var result: Variant = _build_combat_result(victory)
	result.end_reason = RunData.END_REASON_VICTORY if victory else RunData.END_REASON_DEFEAT

	if _game_manager == null:
		return

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or not is_instance_valid(_game_manager):
		return
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
