## ENet transport for local, LAN, and direct-IP multiplayer sessions.
class_name ENetTransport
extends NetworkTransport

const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_PORT := 7000
const DEFAULT_MAX_CLIENTS := 4

func host_session(config: Dictionary) -> Error:
	var port := int(config.get("port", DEFAULT_PORT))
	var max_clients := int(config.get("max_clients", DEFAULT_MAX_CLIENTS))

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		active_peer = null
		return error

	active_peer = peer
	return OK

func join_session(config: Dictionary) -> Error:
	var address := str(config.get("address", DEFAULT_ADDRESS))
	var port := int(config.get("port", DEFAULT_PORT))

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		active_peer = null
		return error

	active_peer = peer
	return OK

func close_session() -> void:
	var peer := active_peer as ENetMultiplayerPeer
	if peer != null:
		peer.close()
	active_peer = null

func is_available() -> bool:
	return true

func display_name() -> String:
	return "ENet"
