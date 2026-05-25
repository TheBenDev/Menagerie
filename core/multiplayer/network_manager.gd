## Autoload that owns multiplayer session state, transports input commands, and distributes authoritative snapshots.
extends Node

const NetworkCommandIdsScript := preload("res://core/multiplayer/network_command_ids.gd")
const NetworkPlayerStateScript := preload("res://core/multiplayer/network_player_state.gd")
const NetworkSessionStateScript := preload("res://core/multiplayer/network_session_state.gd")
const NetworkSnapshotServiceScript := preload("res://core/multiplayer/network_snapshot_service.gd")
const ENetTransportScript := preload("res://core/multiplayer/enet_transport.gd")

signal session_mode_changed(mode: String)
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal authoritative_snapshot_received(snapshot: Dictionary)
signal route_received(scene_ref: String, payload: Dictionary)
signal command_rejected(request_id: String, reason: String, payload: Dictionary)
signal player_list_changed(players: Dictionary)

var session_state: Variant = NetworkSessionStateScript.new()
var active_transport: Variant = null
var local_player_info: Variant = NetworkPlayerStateScript.new(1)
var last_authoritative_snapshot: Dictionary = {}
var _request_sequence: int = 1
var _is_processing_authoritative_travel: bool = false

func _ready() -> void:
	_connect_multiplayer_signals()
	session_state.reset_offline(local_player_info.to_snapshot())

func is_offline() -> bool:
	return session_state.session_mode == NetworkCommandIdsScript.MODE_OFFLINE

func is_host() -> bool:
	return session_state.session_mode == NetworkCommandIdsScript.MODE_HOST

func is_client() -> bool:
	return session_state.session_mode == NetworkCommandIdsScript.MODE_CLIENT

func is_authority() -> bool:
	if is_offline():
		return true
	if not multiplayer.has_multiplayer_peer():
		return false
	if is_host():
		return true
	return multiplayer.is_server()

func has_active_multiplayer_peer() -> bool:
	return multiplayer.has_multiplayer_peer()

func is_connected_client() -> bool:
	return is_client() and has_active_multiplayer_peer() and int(local_player_info.peer_id) > 0

func local_peer_id() -> int:
	if is_offline() or not multiplayer.has_multiplayer_peer():
		return 1
	return multiplayer.get_unique_id()

func host_game(port: int = ENetTransportScript.DEFAULT_PORT, max_clients: int = ENetTransportScript.DEFAULT_MAX_CLIENTS) -> Error:
	close_session()
	active_transport = ENetTransportScript.new()
	var error: Error = active_transport.host_session({
		"port": port,
		"max_clients": max_clients,
	})
	if error != OK:
		active_transport = null
		return error

	var peer: MultiplayerPeer = active_transport.multiplayer_peer()
	if peer == null:
		push_error("ENet host session succeeded but did not produce a MultiplayerPeer.")
		active_transport.close_session()
		active_transport = null
		return ERR_UNCONFIGURED

	multiplayer.multiplayer_peer = peer
	session_state.players_by_peer_id.clear()
	session_state.set_mode(NetworkCommandIdsScript.MODE_HOST)
	_set_local_peer_id(1, "enet")
	_register_player_snapshot(local_player_info.to_snapshot())
	session_mode_changed.emit(session_state.session_mode)
	_broadcast_player_list()
	return OK

func join_game(address: String = ENetTransportScript.DEFAULT_ADDRESS, port: int = ENetTransportScript.DEFAULT_PORT) -> Error:
	close_session()
	active_transport = ENetTransportScript.new()
	var error: Error = active_transport.join_session({
		"address": address,
		"port": port,
	})
	if error != OK:
		active_transport = null
		return error

	var peer: MultiplayerPeer = active_transport.multiplayer_peer()
	if peer == null:
		push_error("ENet join session succeeded but did not produce a MultiplayerPeer.")
		active_transport.close_session()
		active_transport = null
		return ERR_UNCONFIGURED

	multiplayer.multiplayer_peer = peer
	session_state.players_by_peer_id.clear()
	session_state.set_mode(NetworkCommandIdsScript.MODE_CLIENT)
	_set_local_peer_id(0, "enet")
	session_mode_changed.emit(session_state.session_mode)
	return OK

func close_session() -> void:
	if active_transport != null:
		active_transport.close_session()
	active_transport = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_set_local_peer_id(1, "offline")
	session_state.reset_offline(local_player_info.to_snapshot())
	session_mode_changed.emit(session_state.session_mode)
	player_list_changed.emit(session_state.get_players_snapshot())

func set_local_player_info(display_name: String, selected_character_id: String = RunData.DEFAULT_CHARACTER, is_ready: bool = false) -> void:
	local_player_info.configure({
		"peer_id": local_peer_id(),
		"display_name": display_name,
		"selected_character_id": selected_character_id,
		"ready": is_ready,
		"platform": local_player_info.platform,
		"platform_user_id": local_player_info.platform_user_id,
	})
	if is_connected_client():
		rpc_register_player.rpc_id(1, local_player_info.to_snapshot())
	elif not is_client():
		_register_player_snapshot(local_player_info.to_snapshot())
		if is_host():
			_broadcast_player_list()

func get_players_snapshot() -> Dictionary:
	return session_state.get_players_snapshot()

func request_start_run(payload: Dictionary) -> void:
	_submit_command(NetworkCommandIdsScript.START_RUN, payload)

func request_route(scene_ref: String, payload: Dictionary = {}) -> void:
	var route_payload := payload.duplicate(true)
	route_payload["scene_ref"] = scene_ref
	_submit_command(NetworkCommandIdsScript.ROUTE, route_payload)

func request_pawn_travel(pawn_id: String, destination_node_id: int) -> void:
	_submit_command(NetworkCommandIdsScript.PAWN_TRAVEL, {
		"pawn_id": pawn_id,
		"destination_node_id": destination_node_id,
	})

func request_encounter_choice(payload: Dictionary) -> void:
	_submit_command(NetworkCommandIdsScript.ENCOUNTER_CHOICE, payload)

func request_combat_action(payload: Dictionary) -> void:
	_submit_command(NetworkCommandIdsScript.COMBAT_ACTION, payload)

func request_class_reward_choice(payload: Dictionary) -> void:
	_submit_command(NetworkCommandIdsScript.CLASS_REWARD_CHOICE, payload)

func broadcast_route(scene_ref: String, payload: Dictionary = {}) -> void:
	if not is_authority():
		push_error("Only the authoritative peer can broadcast routes.")
		return
	if not NetworkSnapshotServiceScript.is_plain_payload(payload, "route_payload"):
		push_error("Route payload contains non-network data.")
		return
	var plain_payload: Variant = NetworkSnapshotServiceScript.plain_copy(payload, "route_payload")
	if not (plain_payload is Dictionary):
		push_error("Route payload must be a plain Dictionary.")
		return

	if is_offline() or not multiplayer.has_multiplayer_peer():
		_apply_route(scene_ref, plain_payload)
	else:
		rpc_receive_route.rpc(scene_ref, plain_payload)

func broadcast_run_snapshot(reason: String = "") -> void:
	if not is_authority():
		push_error("Only the authoritative peer can broadcast run snapshots.")
		return
	var game_manager: Variant = _game_manager()
	if game_manager == null or not game_manager.has_method("get_run_snapshot"):
		push_error("NetworkManager cannot broadcast a run snapshot without GameManager.get_run_snapshot().")
		return
	var snapshot: Dictionary = game_manager.get_run_snapshot()
	snapshot["snapshot_reason"] = reason
	if not NetworkSnapshotServiceScript.is_plain_payload(snapshot, "run_snapshot"):
		push_error("Run snapshot contains non-network data.")
		return
	var plain_snapshot: Variant = NetworkSnapshotServiceScript.plain_copy(snapshot, "run_snapshot")
	if not (plain_snapshot is Dictionary):
		push_error("Run snapshot contains non-network data.")
		return

	if is_offline() or not multiplayer.has_multiplayer_peer():
		apply_authoritative_snapshot(plain_snapshot)
	else:
		rpc_receive_snapshot.rpc(plain_snapshot)

func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	if not NetworkSnapshotServiceScript.is_plain_payload(snapshot, "authoritative_snapshot"):
		push_error("Received authoritative snapshot contains non-network data.")
		return
	var plain_snapshot: Variant = NetworkSnapshotServiceScript.plain_copy(snapshot, "authoritative_snapshot")
	if not (plain_snapshot is Dictionary):
		push_error("Received invalid authoritative snapshot.")
		return
	last_authoritative_snapshot = plain_snapshot.duplicate(true)
	authoritative_snapshot_received.emit(last_authoritative_snapshot)

@rpc("any_peer", "reliable")
func rpc_register_player(player_info: Dictionary) -> void:
	if not is_authority():
		push_error("Only the authoritative peer can register remote players.")
		return
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		sender_peer_id = local_peer_id()
	var info := player_info.duplicate(true)
	info["peer_id"] = sender_peer_id
	info["platform"] = str(info.get("platform", "enet"))
	_register_player_snapshot(info)
	_broadcast_player_list()

@rpc("authority", "call_local", "reliable")
func rpc_receive_player_list(players_snapshot: Dictionary) -> void:
	session_state.players_by_peer_id.clear()
	for raw_info in players_snapshot.values():
		if raw_info is Dictionary:
			session_state.upsert_player(raw_info)
	player_list_changed.emit(session_state.get_players_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_command(command_id: String, payload: Dictionary, request_id: String) -> void:
	if not is_authority():
		push_error("Non-authoritative peer received a submitted command: %s." % command_id)
		return
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		sender_peer_id = local_peer_id()
	_handle_authoritative_command(sender_peer_id, command_id, payload, request_id)

@rpc("authority", "call_local", "reliable")
func rpc_receive_snapshot(snapshot: Dictionary) -> void:
	apply_authoritative_snapshot(snapshot)

@rpc("authority", "call_local", "reliable")
func rpc_receive_route(scene_ref: String, payload: Dictionary) -> void:
	_apply_route(scene_ref, payload)

@rpc("authority", "call_local", "reliable")
func rpc_receive_command_rejection(request_id: String, reason: String, payload: Dictionary) -> void:
	command_rejected.emit(request_id, reason, payload)

func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _submit_command(command_id: String, payload: Dictionary) -> void:
	if not NetworkSnapshotServiceScript.is_plain_payload(payload, "%s_payload" % command_id):
		push_error("Command %s payload contains non-network data." % command_id)
		return
	var plain_payload: Variant = NetworkSnapshotServiceScript.plain_copy(payload, "%s_payload" % command_id)
	if not (plain_payload is Dictionary):
		push_error("Command %s payload must be a plain Dictionary." % command_id)
		return
	var request_id: String = _next_request_id()
	if is_authority():
		_handle_authoritative_command(local_peer_id(), command_id, plain_payload, request_id)
	elif multiplayer.has_multiplayer_peer():
		rpc_submit_command.rpc_id(1, command_id, plain_payload, request_id)
	else:
		push_error("Client command %s cannot be sent without an active multiplayer peer." % command_id)

func _handle_authoritative_command(sender_peer_id: int, command_id: String, payload: Dictionary, request_id: String) -> void:
	match command_id:
		NetworkCommandIdsScript.START_RUN:
			_handle_start_run(sender_peer_id, payload, request_id)
		NetworkCommandIdsScript.ROUTE:
			_handle_route(sender_peer_id, payload, request_id)
		NetworkCommandIdsScript.PAWN_TRAVEL:
			_handle_pawn_travel(sender_peer_id, payload, request_id)
		NetworkCommandIdsScript.ENCOUNTER_CHOICE:
			_handle_encounter_choice(sender_peer_id, payload, request_id)
		NetworkCommandIdsScript.COMBAT_ACTION:
			_handle_combat_action(sender_peer_id, payload, request_id)
		NetworkCommandIdsScript.CLASS_REWARD_CHOICE:
			_handle_class_reward_choice(sender_peer_id, payload, request_id)
		_:
			_reject_command(sender_peer_id, request_id, "unknown_command", payload)

func _handle_start_run(sender_peer_id: int, payload: Dictionary, request_id: String) -> void:
	if sender_peer_id != 1 and is_host():
		_reject_command(sender_peer_id, request_id, "only_host_can_start_run", payload)
		return
	var game_manager: Variant = _game_manager()
	if game_manager == null or not game_manager.has_method("start_new_run_from_network"):
		push_error("GameManager.start_new_run_from_network is required before network start-run commands can execute.")
		return
	game_manager.start_new_run_from_network(payload)
	broadcast_run_snapshot("start_run")
	broadcast_route(NetworkCommandIdsScript.ROUTE_DUNGEON)

func _handle_route(sender_peer_id: int, payload: Dictionary, request_id: String) -> void:
	var scene_ref: String = str(payload.get("scene_ref", "")).strip_edges()
	if scene_ref.is_empty():
		_reject_command(sender_peer_id, request_id, "missing_scene_ref", payload)
		return
	if is_host() and sender_peer_id != 1 and not _is_client_allowed_route(scene_ref):
		_reject_command(sender_peer_id, request_id, "client_route_rejected", payload)
		return
	broadcast_route(scene_ref, payload)

func _handle_pawn_travel(sender_peer_id: int, payload: Dictionary, request_id: String) -> void:
	var dungeon_manager: Variant = _dungeon_manager()
	if dungeon_manager == null or not dungeon_manager.has_method("server_request_pawn_travel"):
		push_error("DungeonManager.server_request_pawn_travel is required before pawn travel commands can execute.")
		return
	var result: Dictionary = dungeon_manager.server_request_pawn_travel(
		_current_run_data(),
		sender_peer_id,
		str(payload.get("pawn_id", "")),
		int(payload.get("destination_node_id", -1))
	)
	if not bool(result.get("accepted", false)):
		_reject_command(sender_peer_id, request_id, str(result.get("reason", "pawn_travel_rejected")), payload)
		return
	var can_process_travel_now := _can_process_authoritative_travel()
	if not can_process_travel_now:
		broadcast_run_snapshot("pawn_travel_requested")
	if can_process_travel_now:
		_start_authoritative_travel_processing()

func _handle_encounter_choice(sender_peer_id: int, payload: Dictionary, request_id: String) -> void:
	var dungeon_manager: Variant = _dungeon_manager()
	if dungeon_manager == null or not dungeon_manager.has_method("server_resolve_encounter_choice"):
		push_error("DungeonManager.server_resolve_encounter_choice is required before encounter commands can execute.")
		return
	var result: Dictionary = dungeon_manager.server_resolve_encounter_choice(_current_run_data(), sender_peer_id, payload)
	if not bool(result.get("accepted", false)):
		_reject_command(sender_peer_id, request_id, str(result.get("reason", "encounter_choice_rejected")), payload)
		return
	broadcast_run_snapshot("encounter_choice")

func _handle_combat_action(sender_peer_id: int, payload: Dictionary, request_id: String) -> void:
	var combat_manager: Variant = _combat_manager()
	if combat_manager == null or not combat_manager.has_method("server_request_combat_action"):
		push_error("CombatManager.server_request_combat_action is required before combat commands can execute.")
		return
	var result: Dictionary = combat_manager.server_request_combat_action(sender_peer_id, payload)
	if not bool(result.get("accepted", false)):
		_reject_command(sender_peer_id, request_id, str(result.get("reason", "combat_action_rejected")), payload)
		return
	broadcast_run_snapshot("combat_action")

func _handle_class_reward_choice(sender_peer_id: int, payload: Dictionary, request_id: String) -> void:
	var game_manager: Variant = _game_manager()
	if game_manager == null or not game_manager.has_method("server_select_class_reward"):
		push_error("GameManager.server_select_class_reward is required before class reward commands can execute.")
		return
	var result: Dictionary = game_manager.server_select_class_reward(sender_peer_id, payload)
	if not bool(result.get("accepted", false)):
		_reject_command(sender_peer_id, request_id, str(result.get("reason", "class_reward_rejected")), payload)
		return
	broadcast_run_snapshot("class_reward_choice")

func _start_authoritative_travel_processing() -> void:
	if _is_processing_authoritative_travel:
		return
	var dungeon_manager: Variant = _dungeon_manager()
	if dungeon_manager == null:
		push_error("DungeonManager is required before travel can advance.")
		return
	var missing_methods: Array[String] = []
	for method_name: String in [
		"server_advance_travel_one_step",
		"has_active_travel_orders",
		"are_active_travel_orders_ready",
		"visual_node_steps_per_real_second",
		"should_delay_after_travel_step",
	]:
		if not dungeon_manager.has_method(method_name):
			missing_methods.append(method_name)
	if not missing_methods.is_empty():
		push_error("DungeonManager is missing authoritative travel methods: %s." % ", ".join(missing_methods))
		return
	if not _can_process_authoritative_travel():
		return
	_process_authoritative_travel_steps(dungeon_manager)

func _process_authoritative_travel_steps(dungeon_manager: Variant) -> void:
	_is_processing_authoritative_travel = true
	while dungeon_manager.has_active_travel_orders(_current_run_data()):
		var result: Dictionary = dungeon_manager.server_advance_travel_one_step(_current_run_data())
		var reason: String = str(result.get("reason", "travel_step"))
		if not bool(result.get("accepted", false)):
			push_error("Authoritative dungeon travel failed: %s." % reason)
			break

		broadcast_run_snapshot(reason)
		var route_ref: String = str(result.get("route_ref", ""))
		if not route_ref.is_empty():
			broadcast_route(route_ref, result.get("route_payload", {}))
		if reason != "travel_step":
			break
		if not bool(dungeon_manager.call("should_delay_after_travel_step", _current_run_data(), result.get("step_result", {}))):
			continue

		var steps_per_second: float = float(dungeon_manager.visual_node_steps_per_real_second())
		if steps_per_second <= 0.0:
			push_error("Dungeon travel visual step rate must be positive.")
			break
		await get_tree().create_timer(1.0 / steps_per_second).timeout
	_is_processing_authoritative_travel = false

func _apply_route(scene_ref: String, payload: Dictionary) -> void:
	route_received.emit(scene_ref, payload)
	var game_manager: Variant = _game_manager()
	if game_manager == null or not game_manager.has_method("apply_scene_route"):
		push_error("GameManager.apply_scene_route is required before network routes can apply.")
		return
	game_manager.apply_scene_route(scene_ref)

func _register_player_snapshot(player_info: Dictionary) -> void:
	var snapshot: Dictionary = session_state.upsert_player(player_info)
	if snapshot.is_empty():
		return
	player_connected.emit(int(snapshot.get("peer_id", 0)), snapshot)
	player_list_changed.emit(session_state.get_players_snapshot())

func _broadcast_player_list() -> void:
	var players_snapshot: Dictionary = session_state.get_players_snapshot()
	if is_host() and multiplayer.has_multiplayer_peer():
		rpc_receive_player_list.rpc(players_snapshot)
	else:
		player_list_changed.emit(players_snapshot)

func _reject_command(sender_peer_id: int, request_id: String, reason: String, payload: Dictionary) -> void:
	push_error("Rejected network command %s from peer %s: %s." % [request_id, sender_peer_id, reason])
	if is_host() and sender_peer_id != 1 and multiplayer.has_multiplayer_peer():
		rpc_receive_command_rejection.rpc_id(sender_peer_id, request_id, reason, payload)
	else:
		command_rejected.emit(request_id, reason, payload)

func _on_peer_connected(peer_id: int) -> void:
	if is_authority() and peer_id != 1:
		_broadcast_player_list()

func _on_peer_disconnected(peer_id: int) -> void:
	session_state.remove_player(peer_id)
	player_disconnected.emit(peer_id)
	player_list_changed.emit(session_state.get_players_snapshot())
	if is_host():
		_broadcast_player_list()

func _on_connected_to_server() -> void:
	_set_local_peer_id(multiplayer.get_unique_id(), "enet")
	session_state.set_mode(NetworkCommandIdsScript.MODE_CLIENT)
	connected_to_server.emit()
	session_mode_changed.emit(session_state.session_mode)
	rpc_register_player.rpc_id(1, local_player_info.to_snapshot())

func _on_connection_failed() -> void:
	close_session()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	close_session()
	server_disconnected.emit()

func _set_local_peer_id(peer_id: int, platform: String) -> void:
	local_player_info.configure({
		"peer_id": peer_id,
		"display_name": local_player_info.display_name,
		"selected_character_id": local_player_info.selected_character_id,
		"ready": local_player_info.ready,
		"platform": platform,
		"platform_user_id": local_player_info.platform_user_id,
	})

func _next_request_id() -> String:
	var request_id: String = "peer_%s_%s" % [local_peer_id(), _request_sequence]
	_request_sequence += 1
	return request_id

func _is_client_allowed_route(scene_ref: String) -> bool:
	return scene_ref == NetworkCommandIdsScript.ROUTE_MAIN_MENU or scene_ref == NetworkCommandIdsScript.ROUTE_WAITING_ROOM

func _can_process_authoritative_travel() -> bool:
	var dungeon_manager: Variant = _dungeon_manager()
	if dungeon_manager == null or not dungeon_manager.has_method("are_active_travel_orders_ready"):
		return false

	return bool(dungeon_manager.call("are_active_travel_orders_ready", _current_run_data()))

func _game_manager() -> Variant:
	return get_node_or_null("/root/GameManager")

func _dungeon_manager() -> Variant:
	return get_node_or_null("/root/DungeonManager")

func _combat_manager() -> Variant:
	return get_node_or_null("/root/CombatManager")

func _current_run_data() -> Variant:
	var game_manager: Variant = _game_manager()
	if game_manager == null or not game_manager.has_method("get_current_run_reference"):
		return null
	return game_manager.get_current_run_reference()
