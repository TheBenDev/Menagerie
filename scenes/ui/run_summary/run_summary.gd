## Run summary screen that displays final run stats and exports earned memories before returning to setup.
extends Control

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")

@onready var title_label: Label = $MarginContainer/Layout/TitleLabel
@onready var character_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/CharacterValue
@onready var difficulty_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/DifficultyValue
@onready var fights_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/FightsValue
@onready var boss_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/BossValue
@onready var damage_dealt_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/DamageDealtValue
@onready var damage_taken_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/DamageTakenValue
@onready var actions_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/ActionsValue
@onready var time_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/TimeValue
@onready var memories_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/MemoriesValue
@onready var gold_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/GoldValue
@onready var reason_value: Label = $MarginContainer/Layout/SummaryPanel/PanelMargin/SummaryGrid/ReasonValue
@onready var return_button: Button = $MarginContainer/Layout/ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	_apply_number_fonts()
	_refresh_summary()

func _apply_number_fonts() -> void:
	for label in [
		fights_value,
		damage_dealt_value,
		damage_taken_value,
		actions_value,
		time_value,
		memories_value,
		gold_value,
	]:
		NumberFontHelper.apply_to_label(label)

func _refresh_summary() -> void:
	var run_data: Variant = GameManager.current_run_data
	if run_data == null:
		title_label.text = "Run Summary"
		_set_empty_values()
		return

	GameManager.export_current_run_memories()

	title_label.text = _title_for(run_data)
	character_value.text = run_data.selected_character
	difficulty_value.text = GameManager.get_selected_difficulty_display_name()
	fights_value.text = str(run_data.fights_completed)
	boss_value.text = "Yes" if run_data.boss_defeated else "No"
	damage_dealt_value.text = str(run_data.damage_dealt)
	damage_taken_value.text = str(run_data.damage_taken)
	actions_value.text = str(run_data.actions_used)
	time_value.text = "%ss" % int(round(run_data.time_elapsed))
	memories_value.text = str(run_data.memories)
	gold_value.text = str(run_data.gold)
	reason_value.text = _reason_text(run_data.run_end_reason)

func _set_empty_values() -> void:
	character_value.text = "-"
	difficulty_value.text = "-"
	fights_value.text = "0"
	boss_value.text = "No"
	damage_dealt_value.text = "0"
	damage_taken_value.text = "0"
	actions_value.text = "0"
	time_value.text = "0s"
	memories_value.text = "0"
	gold_value.text = "0"
	reason_value.text = "-"

func _title_for(run_data: Variant) -> String:
	if run_data.run_victory:
		return "Run Complete"
	if run_data.run_end_reason == RunData.END_REASON_TIMEOUT:
		return "Time Expired"

	return "Run Ended"

func _reason_text(reason: String) -> String:
	match reason:
		RunData.END_REASON_VICTORY:
			return "Victory"
		RunData.END_REASON_TIMEOUT:
			return "Time Out"
		RunData.END_REASON_DEFEAT:
			return "Defeat"
		_:
			return reason.capitalize()

func _on_return_pressed() -> void:
	SoundManager.play_sfx(&"sfx.global.death.run_ends_loop")
	GameManager.clear_run()
	GameManager.go_to_scene("waiting_room")
