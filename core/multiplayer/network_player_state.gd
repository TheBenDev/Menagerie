## Stores plain session metadata for one connected player.
class_name NetworkPlayerState
extends RefCounted

var peer_id: int = 1
var display_name: String = "Player"
var selected_character_id: String = "Warrior"
var ready: bool = false
var platform: String = "offline"
var platform_user_id: String = ""

func _init(new_peer_id: int = 1) -> void:
	peer_id = max(new_peer_id, 0)

func configure(info: Dictionary) -> void:
	peer_id = int(info.get("peer_id", peer_id))
	display_name = str(info.get("display_name", display_name)).strip_edges()
	if display_name.is_empty():
		display_name = "Player %s" % max(peer_id, 1)
	selected_character_id = str(info.get("selected_character_id", selected_character_id)).strip_edges()
	if selected_character_id.is_empty():
		selected_character_id = "Warrior"
	ready = bool(info.get("ready", ready))
	platform = str(info.get("platform", platform)).strip_edges()
	if platform.is_empty():
		platform = "offline"
	platform_user_id = str(info.get("platform_user_id", platform_user_id)).strip_edges()

func to_snapshot() -> Dictionary:
	return {
		"peer_id": int(peer_id),
		"display_name": display_name,
		"selected_character_id": selected_character_id,
		"ready": ready,
		"platform": platform,
		"platform_user_id": platform_user_id,
	}
