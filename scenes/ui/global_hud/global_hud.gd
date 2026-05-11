## Persistent HUD layer for run timer, currencies, and selected character stats.
extends CanvasLayer

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")

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

func _ready() -> void:
	player_button.pressed.connect(_on_player_button_pressed)
	_connect_game_manager_signals()
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
	]:
		NumberFontHelper.apply_to_label(label)

func _connect_game_manager_signals() -> void:
	if not _has_game_manager():
		return

	if not GameManager.run_time_changed.is_connected(_on_run_time_changed):
		GameManager.run_time_changed.connect(_on_run_time_changed)
	if not GameManager.run_currencies_changed.is_connected(_on_run_currencies_changed):
		GameManager.run_currencies_changed.connect(_on_run_currencies_changed)

func _refresh_all() -> void:
	_refresh_player_panel()

	if not _has_game_manager() or GameManager.current_run_data == null:
		_on_run_time_changed(0.0, 300.0)
		_on_run_currencies_changed(0, 0)
		return

	var run_data: Variant = GameManager.current_run_data
	_on_run_time_changed(run_data.remaining_run_time_seconds, run_data.max_run_time_seconds)
	_on_run_currencies_changed(run_data.memories, run_data.gold)

func _on_run_time_changed(remaining_time_seconds: float, max_time_seconds: float) -> void:
	timer_bar.set_timer_values(remaining_time_seconds, max_time_seconds)
	timer_label.text = _format_time(remaining_time_seconds)

func _on_run_currencies_changed(memories: int, gold: int) -> void:
	memories_value.text = str(max(memories, 0))
	gold_value.text = str(max(gold, 0))

func _on_player_button_pressed() -> void:
	player_panel.visible = not player_panel.visible

func _refresh_player_panel() -> void:
	if not _has_game_manager():
		character_value.text = "Warrior"
		_set_stat_values(null)
		return

	var profile: CombatantProfile = GameManager.get_selected_character_profile()
	if profile == null:
		character_value.text = GameManager.get_selected_character_id()
		_set_stat_values(null)
		return

	var display_name := profile.display_name
	character_value.text = display_name if not display_name.is_empty() else GameManager.get_selected_character_id()
	_set_stat_values(profile)

func _set_stat_values(profile: CombatantProfile) -> void:
	strength_value.text = _profile_stat(profile, "strength")
	dexterity_value.text = _profile_stat(profile, "dexterity")
	intelligence_value.text = _profile_stat(profile, "intelligence")
	vitality_value.text = _profile_stat(profile, "vitality")

func _profile_stat(profile: CombatantProfile, field_name: String) -> String:
	if profile == null:
		return "-"

	match field_name:
		"strength":
			return str(profile.strength)
		"dexterity":
			return str(profile.dexterity)
		"intelligence":
			return str(profile.intelligence)
		"vitality":
			return str(profile.vitality)
		_:
			return "-"

func _format_time(value: float) -> String:
	var total_seconds: int = max(int(ceil(value)), 0)
	var minutes: int = int(floor(float(total_seconds) / 60.0))
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _has_game_manager() -> bool:
	return get_node_or_null("/root/GameManager") != null
