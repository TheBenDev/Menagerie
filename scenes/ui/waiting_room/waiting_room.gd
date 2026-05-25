## Setup screen for selecting character and difficulty before starting a new dungeon run.
extends Control

const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := RunData.DEFAULT_DIFFICULTY
const DIFFICULTY_HARD := "hard"

@onready var warrior_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/CharacterRow/WarriorButton
@onready var easy_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/DifficultyRow/EasyButton
@onready var normal_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/DifficultyRow/NormalButton
@onready var hard_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/DifficultyRow/HardButton
@onready var seed_edit: LineEdit = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/SeedRow/SeedEdit
@onready var start_run_button: Button = $MarginContainer/Layout/ActionRow/StartRunButton
@onready var back_button: Button = $MarginContainer/Layout/ActionRow/BackButton
@onready var setup_layout: VBoxContainer = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout

var selected_character: String = RunData.DEFAULT_CHARACTER
var selected_difficulty: String = DIFFICULTY_NORMAL
var player_list_label: Label = null
var ready_button: Button = null
var host_button: Button = null
var join_button: Button = null
var address_edit: LineEdit = null
var port_spin: SpinBox = null
var connection_status_label: Label = null

func _ready() -> void:
	call_deferred("_request_scene_music")
	_create_network_controls()
	_connect_network_signals()
	selected_difficulty = GameManager.get_selected_difficulty_id()
	if selected_difficulty.is_empty():
		selected_difficulty = DIFFICULTY_NORMAL

	if PartyManager.has_character(selected_character):
		warrior_button.text = PartyManager.get_character_display_name(selected_character)
	else:
		push_error("Waiting room selected unknown default character: %s." % selected_character)
	warrior_button.button_pressed = true
	warrior_button.pressed.connect(_on_character_pressed.bind(selected_character))
	easy_button.pressed.connect(_set_difficulty.bind(DIFFICULTY_EASY))
	normal_button.pressed.connect(_set_difficulty.bind(DIFFICULTY_NORMAL))
	hard_button.pressed.connect(_set_difficulty.bind(DIFFICULTY_HARD))
	start_run_button.pressed.connect(_on_start_run_pressed)
	back_button.pressed.connect(_on_back_pressed)
	NetworkManager.set_local_player_info(_default_display_name(), selected_character, false)
	_refresh_difficulty_buttons()
	_refresh_network_controls()

func _request_scene_music() -> void:
	GameManager.play_music_for_scene("waiting_room")

func _set_difficulty(difficulty: String) -> void:
	selected_difficulty = difficulty
	_refresh_difficulty_buttons()

func _on_character_pressed(character_id: String) -> void:
	if not PartyManager.has_character(character_id):
		push_error("Waiting room cannot select unknown character: %s." % character_id)
		return
	selected_character = character_id
	warrior_button.button_pressed = true
	NetworkManager.set_local_player_info(_default_display_name(), selected_character, _local_ready())

func _refresh_difficulty_buttons() -> void:
	easy_button.button_pressed = selected_difficulty == DIFFICULTY_EASY
	normal_button.button_pressed = selected_difficulty == DIFFICULTY_NORMAL
	hard_button.button_pressed = selected_difficulty == DIFFICULTY_HARD

func _on_start_run_pressed() -> void:
	if not NetworkManager.is_authority():
		push_error("Only the authoritative peer can start a run.")
		return
	if not _can_start_run():
		push_error("Cannot start multiplayer run until every connected player is ready.")
		return
	var member_configs := PartyManager.build_member_configs_from_network_players(NetworkManager.get_players_snapshot())
	if member_configs.is_empty():
		push_error("Cannot start run without valid party member configs.")
		return
	NetworkManager.request_start_run({
		"character": selected_character,
		"difficulty": selected_difficulty,
		"dungeon_seed": seed_edit.text.strip_edges(),
		"dungeon_floor_layer": 1,
		"member_configs": member_configs,
	})

func _on_back_pressed() -> void:
	if NetworkManager.is_client() and not NetworkManager.is_connected_client():
		NetworkManager.close_session()
	NetworkManager.request_route("main_menu")

func _create_network_controls() -> void:
	var network_label := Label.new()
	network_label.text = "Network"
	network_label.theme_type_variation = &"HeaderLabel"
	setup_layout.add_child(network_label)

	var network_row := HBoxContainer.new()
	network_row.add_theme_constant_override("separation", 10)
	setup_layout.add_child(network_row)

	host_button = Button.new()
	host_button.custom_minimum_size = Vector2(150, 54)
	host_button.text = "Host"
	host_button.pressed.connect(_on_host_pressed)
	network_row.add_child(host_button)

	join_button = Button.new()
	join_button.custom_minimum_size = Vector2(150, 54)
	join_button.text = "Join"
	join_button.pressed.connect(_on_join_pressed)
	network_row.add_child(join_button)

	ready_button = Button.new()
	ready_button.custom_minimum_size = Vector2(150, 54)
	ready_button.toggle_mode = true
	ready_button.text = "Ready"
	ready_button.toggled.connect(_on_ready_toggled)
	network_row.add_child(ready_button)

	var connection_row := HBoxContainer.new()
	connection_row.add_theme_constant_override("separation", 10)
	setup_layout.add_child(connection_row)

	address_edit = LineEdit.new()
	address_edit.custom_minimum_size = Vector2(320, 54)
	address_edit.placeholder_text = "Host IP or domain"
	address_edit.text = ENetTransport.DEFAULT_ADDRESS
	address_edit.clear_button_enabled = true
	connection_row.add_child(address_edit)

	port_spin = SpinBox.new()
	port_spin.custom_minimum_size = Vector2(140, 54)
	port_spin.min_value = 1
	port_spin.max_value = 65535
	port_spin.step = 1
	port_spin.value = ENetTransport.DEFAULT_PORT
	connection_row.add_child(port_spin)

	connection_status_label = Label.new()
	connection_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_status_label.text = "Host locally, join by LAN IP, public IP, or VPN IP."
	setup_layout.add_child(connection_status_label)

	player_list_label = Label.new()
	player_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_layout.add_child(player_list_label)

func _connect_network_signals() -> void:
	if not NetworkManager.player_list_changed.is_connected(_on_player_list_changed):
		NetworkManager.player_list_changed.connect(_on_player_list_changed)
	if not NetworkManager.session_mode_changed.is_connected(_on_session_mode_changed):
		NetworkManager.session_mode_changed.connect(_on_session_mode_changed)
	if not NetworkManager.connected_to_server.is_connected(_on_connected_to_server):
		NetworkManager.connected_to_server.connect(_on_connected_to_server)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
		NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	if NetworkManager.is_host():
		_cancel_network_session("Stopped hosting.")
		return
	if not NetworkManager.is_offline():
		push_error("Cannot host while another network session is active.")
		return

	var port := _network_port()
	var error: Error = NetworkManager.host_game(port)
	if error != OK:
		push_error("Host session failed on UDP port %s. Error: %s." % [port, error])
		_set_connection_status("Host failed on UDP port %s. Error: %s." % [port, error])
		_refresh_network_controls()
		return

	NetworkManager.set_local_player_info(_default_display_name(), selected_character, _local_ready())
	_set_connection_status("Hosting on UDP port %s. External clients should join your public IP or VPN IP." % port)
	_refresh_network_controls()

func _on_join_pressed() -> void:
	if NetworkManager.is_client():
		_cancel_network_session("Join cancelled.")
		return
	if not NetworkManager.is_offline():
		push_error("Cannot join while another network session is active.")
		return

	var address := _network_address()
	var port := _network_port()

	var error: Error = NetworkManager.join_game(address, port)
	if error != OK:
		push_error("Join session failed at %s:%s. Error: %s." % [address, port, error])
		_set_connection_status("Join failed at %s:%s. Error: %s." % [address, port, error])
		_refresh_network_controls()
		return

	_set_connection_status("Joining %s:%s..." % [address, port])
	_refresh_network_controls()

func _cancel_network_session(message: String) -> void:
	NetworkManager.close_session()
	_set_connection_status(message)
	_refresh_network_controls()

func _network_address() -> String:
	var address := "127.0.0.1"
	if address_edit != null:
		address = address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	return address

func _network_port() -> int:
	if port_spin == null:
		return 7000
	return int(port_spin.value)

func _set_connection_status(message: String) -> void:
	if connection_status_label != null:
		connection_status_label.text = message

func _on_ready_toggled(is_ready: bool) -> void:
	NetworkManager.set_local_player_info(_default_display_name(), selected_character, is_ready)
	_refresh_network_controls()

func _on_player_list_changed(_players: Dictionary) -> void:
	_refresh_network_controls()

func _on_session_mode_changed(_mode: String) -> void:
	_refresh_network_controls()

func _on_connected_to_server() -> void:
	_set_connection_status("Connected to host as peer %s." % NetworkManager.local_peer_id())
	NetworkManager.set_local_player_info(_default_display_name(), selected_character, _local_ready())
	_refresh_network_controls()

func _on_connection_failed() -> void:
	_set_connection_status("Connection failed. Check host IP, UDP port forwarding, firewall, or VPN IP.")
	_refresh_network_controls()

func _on_server_disconnected() -> void:
	_set_connection_status("Disconnected from host.")
	_refresh_network_controls()

func _refresh_network_controls() -> void:
	if player_list_label != null:
		player_list_label.text = _player_list_text()
	if ready_button != null:
		ready_button.set_pressed_no_signal(_local_ready())
		ready_button.disabled = not (NetworkManager.is_offline() or NetworkManager.is_host() or NetworkManager.is_connected_client())

	var is_offline: bool = NetworkManager.is_offline()
	var is_hosting: bool = NetworkManager.is_host()
	var is_joining: bool = NetworkManager.is_client()
	if host_button != null:
		host_button.text = "Cancel" if is_hosting else "Host"
		host_button.disabled = is_joining
	if join_button != null:
		join_button.text = "Cancel" if is_joining else "Join"
		join_button.disabled = is_hosting
	if address_edit != null:
		address_edit.editable = is_offline
	if port_spin != null:
		port_spin.editable = is_offline

	start_run_button.disabled = not NetworkManager.is_authority() or not _can_start_run()
	easy_button.disabled = not NetworkManager.is_authority()
	normal_button.disabled = not NetworkManager.is_authority()
	hard_button.disabled = not NetworkManager.is_authority()
	seed_edit.editable = NetworkManager.is_authority()

func _player_list_text() -> String:
	var lines: Array[String] = []
	lines.append("Mode: %s" % NetworkManager.session_state.session_mode.capitalize())
	for player_info in NetworkManager.get_players_snapshot().values():
		var info: Dictionary = player_info
		var ready_text := "Ready" if bool(info.get("ready", false)) else "Not Ready"
		lines.append("%s  %s  %s" % [
			str(info.get("display_name", "Player")),
			str(info.get("selected_character_id", RunData.DEFAULT_CHARACTER)),
			ready_text,
		])
	return "\n".join(lines)

func _can_start_run() -> bool:
	if NetworkManager.is_offline():
		return true
	var players: Dictionary = NetworkManager.get_players_snapshot()
	if players.is_empty():
		return false
	for player_info in players.values():
		var info: Dictionary = player_info
		if not bool(info.get("ready", false)):
			return false
	return true

func _local_ready() -> bool:
	var local_info: Dictionary = NetworkManager.session_state.get_player_snapshot(NetworkManager.local_peer_id())
	return bool(local_info.get("ready", false))

func _default_display_name() -> String:
	var peer_id: int = NetworkManager.local_peer_id()
	return "Player %s" % peer_id
