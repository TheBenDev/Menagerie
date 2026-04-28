extends CanvasLayer

const NumberFontHelper := preload("res://scripts/ui/common/number_font.gd")

@onready var player_button: Button = $HUDRoot/TopMargin/TopBar/BarMargin/BarRow/PlayerButton
@onready var timer_bar: TimeProgressBar = $HUDRoot/TopMargin/TopBar/BarMargin/BarRow/TimerStack/TimerProgress
@onready var timer_label: Label = $HUDRoot/TopMargin/TopBar/BarMargin/BarRow/TimerStack/TimerLabel
@onready var memories_value: Label = $HUDRoot/TopMargin/TopBar/BarMargin/BarRow/CurrencyRow/MemoriesBox/MemoryMargin/MemoryLayout/MemoryValue
@onready var gold_value: Label = $HUDRoot/TopMargin/TopBar/BarMargin/BarRow/CurrencyRow/GoldBox/GoldMargin/GoldLayout/GoldValue
@onready var player_panel: PanelContainer = $HUDRoot/PlayerPanel
@onready var character_value: Label = $HUDRoot/PlayerPanel/PanelMargin/StatsLayout/CharacterValue
@onready var strength_value: Label = $HUDRoot/PlayerPanel/PanelMargin/StatsLayout/StatsGrid/StrengthValue
@onready var dexterity_value: Label = $HUDRoot/PlayerPanel/PanelMargin/StatsLayout/StatsGrid/DexterityValue
@onready var intelligence_value: Label = $HUDRoot/PlayerPanel/PanelMargin/StatsLayout/StatsGrid/IntelligenceValue
@onready var vitality_value: Label = $HUDRoot/PlayerPanel/PanelMargin/StatsLayout/StatsGrid/VitalityValue

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

	var profile := GameManager.get_selected_character_profile()
	if profile == null:
		character_value.text = GameManager.selected_character
		_set_stat_values(null)
		return

	var display_name: String = str(profile.get("display_name"))
	character_value.text = display_name if not display_name.is_empty() else GameManager.selected_character
	player_button.text = str(profile.get("timeline_initial"))
	_set_stat_values(profile)

func _set_stat_values(profile: Resource) -> void:
	strength_value.text = _profile_stat(profile, "strength")
	dexterity_value.text = _profile_stat(profile, "dexterity")
	intelligence_value.text = _profile_stat(profile, "intelligence")
	vitality_value.text = _profile_stat(profile, "vitality")

func _profile_stat(profile: Resource, field_name: String) -> String:
	if profile == null:
		return "-"

	return str(int(profile.get(field_name)))

func _format_time(value: float) -> String:
	var total_seconds: int = max(int(ceil(value)), 0)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _has_game_manager() -> bool:
	return get_node_or_null("/root/GameManager") != null
