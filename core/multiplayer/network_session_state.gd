## Tracks current multiplayer mode and plain metadata for connected peers.
class_name NetworkSessionState
extends RefCounted

const NetworkCommandIdsScript := preload("res://core/multiplayer/network_command_ids.gd")
const NetworkPlayerStateScript := preload("res://core/multiplayer/network_player_state.gd")

var session_mode: String = NetworkCommandIdsScript.MODE_OFFLINE
var players_by_peer_id: Dictionary = {}

func _init() -> void:
	reset_offline()

func reset_offline(local_info: Dictionary = {}) -> void:
	session_mode = NetworkCommandIdsScript.MODE_OFFLINE
	players_by_peer_id.clear()
	var info := {
		"peer_id": 1,
		"display_name": "Player",
		"selected_character_id": "Warrior",
		"ready": false,
		"platform": "offline",
		"platform_user_id": "",
	}
	info.merge(local_info, true)
	upsert_player(info)

func set_mode(new_mode: String) -> void:
	var normalized := new_mode.strip_edges().to_lower()
	match normalized:
		NetworkCommandIdsScript.MODE_OFFLINE, NetworkCommandIdsScript.MODE_HOST, NetworkCommandIdsScript.MODE_CLIENT:
			session_mode = normalized
		_:
			push_error("Invalid network session mode: %s." % new_mode)

func upsert_player(info: Dictionary) -> Dictionary:
	var state: Variant = NetworkPlayerStateScript.new(int(info.get("peer_id", 1)))
	state.configure(info)
	if state.peer_id <= 0:
		push_error("Cannot register network player with invalid peer id: %s." % state.peer_id)
		return {}
	players_by_peer_id[state.peer_id] = state
	return state.to_snapshot()

func remove_player(peer_id: int) -> void:
	players_by_peer_id.erase(peer_id)

func get_player(peer_id: int) -> Variant:
	return players_by_peer_id.get(peer_id, null)

func get_player_snapshot(peer_id: int) -> Dictionary:
	var player: Variant = get_player(peer_id)
	if player == null:
		return {}
	return player.to_snapshot()

func get_players_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for peer_id in sorted_peer_ids():
		var player: Variant = get_player(peer_id)
		if player != null:
			snapshot[str(peer_id)] = player.to_snapshot()
	return snapshot

func sorted_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for raw_peer_id in players_by_peer_id.keys():
		peer_ids.append(int(raw_peer_id))
	peer_ids.sort()
	return peer_ids

func player_count() -> int:
	return players_by_peer_id.size()
