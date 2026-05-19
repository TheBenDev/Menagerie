## Abstract transport interface used by NetworkManager before platform-specific networking is attached.
class_name NetworkTransport
extends RefCounted

var active_peer: MultiplayerPeer = null

func host_session(_config: Dictionary) -> Error:
	push_error("NetworkTransport.host_session must be implemented by a concrete transport.")
	return ERR_UNAVAILABLE

func join_session(_config: Dictionary) -> Error:
	push_error("NetworkTransport.join_session must be implemented by a concrete transport.")
	return ERR_UNAVAILABLE

func close_session() -> void:
	active_peer = null

func multiplayer_peer() -> MultiplayerPeer:
	return active_peer
