extends Control

@onready var start_button: Button = $MarginContainer/CenterContainer/MenuLayout/StartButton
@onready var quit_button: Button = $MarginContainer/CenterContainer/MenuLayout/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	GameManager.go_to_waiting_room()

func _on_quit_pressed() -> void:
	get_tree().quit()
