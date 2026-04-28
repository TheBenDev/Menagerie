extends Control

const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"
const DIFFICULTY_HARD := "hard"

@onready var warrior_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/CharacterRow/WarriorButton
@onready var easy_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/DifficultyRow/EasyButton
@onready var normal_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/DifficultyRow/NormalButton
@onready var hard_button: Button = $MarginContainer/Layout/SetupPanel/PanelMargin/SetupLayout/DifficultyRow/HardButton
@onready var start_run_button: Button = $MarginContainer/Layout/ActionRow/StartRunButton
@onready var back_button: Button = $MarginContainer/Layout/ActionRow/BackButton

var selected_character: String = "Warrior"
var selected_difficulty: String = DIFFICULTY_NORMAL

func _ready() -> void:
	selected_difficulty = GameManager.selected_difficulty
	if selected_difficulty.is_empty():
		selected_difficulty = DIFFICULTY_NORMAL

	warrior_button.button_pressed = true
	warrior_button.pressed.connect(_on_warrior_pressed)
	easy_button.pressed.connect(_set_difficulty.bind(DIFFICULTY_EASY))
	normal_button.pressed.connect(_set_difficulty.bind(DIFFICULTY_NORMAL))
	hard_button.pressed.connect(_set_difficulty.bind(DIFFICULTY_HARD))
	start_run_button.pressed.connect(_on_start_run_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_refresh_difficulty_buttons()

func _set_difficulty(difficulty: String) -> void:
	selected_difficulty = difficulty
	_refresh_difficulty_buttons()

func _on_warrior_pressed() -> void:
	selected_character = "Warrior"
	warrior_button.button_pressed = true

func _refresh_difficulty_buttons() -> void:
	easy_button.button_pressed = selected_difficulty == DIFFICULTY_EASY
	normal_button.button_pressed = selected_difficulty == DIFFICULTY_NORMAL
	hard_button.button_pressed = selected_difficulty == DIFFICULTY_HARD

func _on_start_run_pressed() -> void:
	GameManager.start_new_run(selected_character, selected_difficulty)
	GameManager.go_to_dungeon()

func _on_back_pressed() -> void:
	GameManager.go_to_main_menu()
