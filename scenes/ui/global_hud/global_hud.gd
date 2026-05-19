## Persistent HUD layer for run timer, currencies, and selected character stats.
extends CanvasLayer

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")

@onready var player_button: TextureButton = $HUDRoot/TopLeftPanel/PlayerButton
@onready var timer_bar: TimeProgressBar = $HUDRoot/TopMargin/BarMargin/BarRow/TimerStack/TimerProgress
@onready var timer_label: Label = $HUDRoot/TopMargin/BarMargin/BarRow/TimerStack/TimerLabel
@onready var memories_value: Label = $HUDRoot/TopRightPanel/TopRightMargin/TopRightRow/VBoxContainer/MemoriesItem/MemoriesValue
@onready var gold_value: Label = $HUDRoot/TopRightPanel/TopRightMargin/TopRightRow/VBoxContainer/GoldItem/GoldValue
@onready var player_panel: Control = $HUDRoot/TopLeftPanel/PlayerButton/PlayerPanel
@onready var character_value: Label = $HUDRoot/TopLeftPanel/HeaderRow/CharacterValue
@onready var strength_value: Label = $HUDRoot/TopLeftPanel/PlayerButton/PlayerPanel/PanelMargin/PanelLayout/StatsRow/StrengthStat/StrengthValue
@onready var dexterity_value: Label = $HUDRoot/TopLeftPanel/PlayerButton/PlayerPanel/PanelMargin/PanelLayout/StatsRow/DexterityStat/DexterityValue
@onready var intelligence_value: Label = $HUDRoot/TopLeftPanel/PlayerButton/PlayerPanel/PanelMargin/PanelLayout/StatsRow/IntelligenceStat/IntelligenceValue
@onready var vitality_value: Label = $HUDRoot/TopLeftPanel/PlayerButton/PlayerPanel/PanelMargin/PanelLayout/StatsRow/VitalityStat/VitalityValue
@onready var hp_value: Label = $HUDRoot/TopLeftPanel/PlayerButton/PlayerPanel/PanelMargin/PanelLayout/HealthRow/HealthValue

func _ready() -> void:
	player_button.pressed.connect(_on_player_button_pressed)
	_connect_game_manager_signals()
	_connect_network_manager_signals()
	_apply_number_fonts()
	player_panel.visible = false
	_refresh_all()

func _apply_number_fonts() -> void:
	for label in [
		timer_label,
		memories_value,
		gold_value,
		strength_value,
		dexterity_value,
		intelligence_value,
		vitality_value,
		hp_value,
	]:
		NumberFontHelper.apply_to_label(label)

func _connect_game_manager_signals() -> void:
	if not _has_game_manager():
		return

	if not GameManager.run_time_changed.is_connected(_on_run_time_changed):
		GameManager.run_time_changed.connect(_on_run_time_changed)
	if not GameManager.run_currencies_changed.is_connected(_on_run_currencies_changed):
		GameManager.run_currencies_changed.connect(_on_run_currencies_changed)

func _connect_network_manager_signals() -> void:
	if not _has_network_manager():
		return
	if not NetworkManager.authoritative_snapshot_received.is_connected(_on_authoritative_snapshot_received):
		NetworkManager.authoritative_snapshot_received.connect(_on_authoritative_snapshot_received)

func _refresh_all() -> void:
	_refresh_player_panel()

	var timer_snapshot: Dictionary = _timer_snapshot_for_view()
	var currency_snapshot: Dictionary = _currency_snapshot_for_view()
	_on_run_time_changed(
		float(timer_snapshot.get("remaining_time_seconds", 0.0)),
		float(timer_snapshot.get("max_time_seconds", 300.0))
	)
	_on_run_currencies_changed(
		int(currency_snapshot.get("memories", 0)),
		int(currency_snapshot.get("gold", 0))
	)

func _on_run_time_changed(remaining_time_seconds: float, max_time_seconds: float) -> void:
	timer_bar.set_timer_values(remaining_time_seconds, max_time_seconds)
	timer_label.text = _format_time(remaining_time_seconds)
	_refresh_player_panel()

func _on_run_currencies_changed(memories: int, gold: int) -> void:
	memories_value.text = str(max(memories, 0))
	gold_value.text = str(max(gold, 0))

func _on_authoritative_snapshot_received(_snapshot: Dictionary) -> void:
	_refresh_all()

func _on_player_button_pressed() -> void:
	player_panel.visible = not player_panel.visible

func _refresh_player_panel() -> void:
	var member_snapshot: Dictionary = _local_party_member_snapshot()
	if not member_snapshot.is_empty():
		var profile_path := str(member_snapshot.get("profile_path", "")).strip_edges()
		var profile := load(profile_path) as CombatantProfile if not profile_path.is_empty() else null
		var character_id := str(member_snapshot.get("character_id", "Warrior"))
		if profile != null and not profile.display_name.is_empty():
			character_value.text = profile.display_name
		else:
			character_value.text = character_id
		_set_stat_values_from_snapshot(member_snapshot.get("effective_stats", {}), profile)
		var hp_snapshot: Dictionary = member_snapshot.get("hp", {})
		_set_hp_values(int(hp_snapshot.get("current", 0)), int(hp_snapshot.get("max", 0)))
		return

	if not _has_game_manager():
		character_value.text = "Warrior"
		_set_stat_values(null)
		_set_hp_values(0, 0)
		return

	var profile: CombatantProfile = GameManager.get_selected_character_profile()
	if profile == null:
		character_value.text = GameManager.get_selected_character_id()
		_set_stat_values(null)
		_set_hp_values(0, 0)
		return

	var display_name := profile.display_name
	character_value.text = display_name if not display_name.is_empty() else GameManager.get_selected_character_id()
	_set_stat_values(profile)
	var hp_snapshot: Dictionary = GameManager.get_run_player_hp_snapshot()
	_set_hp_values(int(hp_snapshot.get("current", 0)), int(hp_snapshot.get("max", 0)))

func _set_stat_values(profile: CombatantProfile) -> void:
	if _has_game_manager() and GameManager.has_active_run():
		var effective_stats: Dictionary = GameManager.get_effective_player_stats()
		_set_stat_values_from_snapshot(effective_stats, profile)
		return

	strength_value.text = _profile_stat_text(profile, "strength")
	dexterity_value.text = _profile_stat_text(profile, "dexterity")
	intelligence_value.text = _profile_stat_text(profile, "intelligence")
	vitality_value.text = _profile_stat_text(profile, "vitality")

func _set_stat_values_from_snapshot(raw_stats: Variant, fallback_profile: CombatantProfile = null) -> void:
	if not (raw_stats is Dictionary):
		_set_stat_values(fallback_profile)
		return

	var stats: Dictionary = raw_stats
	strength_value.text = str(int(stats.get(StatId.STR, stats.get(String(StatId.STR), _profile_stat_text(fallback_profile, "strength")))))
	dexterity_value.text = str(int(stats.get(StatId.DEX, stats.get(String(StatId.DEX), _profile_stat_text(fallback_profile, "dexterity")))))
	intelligence_value.text = str(int(stats.get(StatId.INT, stats.get(String(StatId.INT), _profile_stat_text(fallback_profile, "intelligence")))))
	vitality_value.text = str(int(stats.get(StatId.VIT, stats.get(String(StatId.VIT), _profile_stat_text(fallback_profile, "vitality")))))

func _set_hp_values(current_hp: int, max_hp: int) -> void:
	if current_hp <= 0 and max_hp <= 0:
		hp_value.text = "-/-"
		return

	hp_value.text = "%s/%s" % [max(current_hp, 0), max(max_hp, 1)]

func _profile_stat_text(profile: CombatantProfile, field_name: String) -> String:
	if profile == null:
		return "-"

	return str(ValueReaderScript.resource_int(profile, field_name, 0))

func _format_time(value: float) -> String:
	var total_seconds: int = max(int(ceil(value)), 0)
	var minutes: int = int(floor(float(total_seconds) / 60.0))
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _has_game_manager() -> bool:
	return get_node_or_null("/root/GameManager") != null

func _timer_snapshot_for_view() -> Dictionary:
	var snapshot := _authoritative_snapshot_for_view()
	if not snapshot.is_empty():
		var timer_snapshot: Dictionary = snapshot.get("timer", {})
		if not timer_snapshot.is_empty():
			return timer_snapshot

	if _has_game_manager() and GameManager.has_active_run():
		return GameManager.get_timer_snapshot()

	return {
		"remaining_time_seconds": 0.0,
		"max_time_seconds": 300.0,
	}

func _currency_snapshot_for_view() -> Dictionary:
	var snapshot := _authoritative_snapshot_for_view()
	if not snapshot.is_empty():
		var currency_snapshot: Dictionary = snapshot.get("currencies", {})
		if not currency_snapshot.is_empty():
			return currency_snapshot

	if _has_game_manager() and GameManager.has_active_run():
		return GameManager.get_currency_snapshot()

	return {
		"memories": 0,
		"gold": 0,
	}

func _local_party_member_snapshot() -> Dictionary:
	var snapshot := _authoritative_snapshot_for_view()
	if snapshot.is_empty():
		return {}

	var party_snapshot: Dictionary = snapshot.get("party", {})
	var members: Dictionary = party_snapshot.get("members", {})
	if members.is_empty():
		return {}

	var local_peer_id: int = NetworkManager.local_peer_id() if _has_network_manager() else 1
	for raw_member_id in party_snapshot.get("active_member_ids", []):
		var member: Dictionary = members.get(str(raw_member_id), {})
		if not member.is_empty() and int(member.get("owner_peer_id", 1)) == local_peer_id:
			return member

	var selected_member_id := str(party_snapshot.get("selected_member_id", ""))
	var selected_member: Dictionary = members.get(selected_member_id, {})
	if not selected_member.is_empty():
		return selected_member

	for raw_member in members.values():
		if raw_member is Dictionary:
			return raw_member

	return {}

func _authoritative_snapshot_for_view() -> Dictionary:
	if not _has_network_manager() or not NetworkManager.is_client():
		return {}
	if NetworkManager.last_authoritative_snapshot.is_empty():
		return {}

	return NetworkManager.last_authoritative_snapshot

func _has_network_manager() -> bool:
	return get_node_or_null("/root/NetworkManager") != null
