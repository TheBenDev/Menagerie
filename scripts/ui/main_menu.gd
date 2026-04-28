extends Control

@onready var start_button: BaseButton = $MarginContainer/CenterContainer/MenuLayout/StartButton
@onready var escape_button: BaseButton = $MarginContainer/CenterContainer/MenuLayout/EscapeButton
@onready var close_button: BaseButton = $TopRightButtons/CloseButton

func _ready() -> void:
	call_deferred("_request_scene_music")
	start_button.pressed.connect(_on_start_pressed)
	escape_button.pressed.connect(_on_escape_pressed)
	close_button.pressed.connect(_on_close_pressed)

func _request_scene_music() -> void:
	GameManager.play_music_for_scene(GameManager.MAIN_MENU_SCENE_PATH)

func _on_start_pressed() -> void:
	GameManager.go_to_waiting_room()

func _on_escape_pressed() -> void:
	escape_button.hide()

func _on_close_pressed() -> void:
	get_tree().quit()
