## Scene connector that applies shared map navigation keybinds to the dungeon map view.
class_name DungeonMapInputConnector
extends Node

const KeybindsHelperScript := preload("res://core/input/keybinds_helper.gd")

@export var viewport_path: NodePath
@export var map_content_path: NodePath
@export var zoom_step: float = 1.12
@export var min_zoom: float = 0.55
@export var max_zoom: float = 2.0

@onready var viewport: Control = get_node(viewport_path)
@onready var map_content: Control = get_node(map_content_path)

var is_panning: bool = false

func _ready() -> void:
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	if not viewport.gui_input.is_connected(_on_viewport_gui_input):
		viewport.gui_input.connect(_on_viewport_gui_input)

func _on_viewport_gui_input(event: InputEvent) -> void:
	var action := KeybindsHelperScript.process_map_navigation_event(event, is_panning)
	match action.get(KeybindsHelperScript.KEY_ACTION, KeybindsHelperScript.ACTION_NONE):
		KeybindsHelperScript.ACTION_ZOOM_IN:
			_zoom_at_viewport_position(float(zoom_step), action.get(KeybindsHelperScript.KEY_POSITION, Vector2.ZERO))
			viewport.accept_event()
		KeybindsHelperScript.ACTION_ZOOM_OUT:
			_zoom_at_viewport_position(1.0 / float(zoom_step), action.get(KeybindsHelperScript.KEY_POSITION, Vector2.ZERO))
			viewport.accept_event()
		KeybindsHelperScript.ACTION_PAN_START:
			is_panning = true
			viewport.accept_event()
		KeybindsHelperScript.ACTION_PAN_MOVE:
			map_content.position += action.get(KeybindsHelperScript.KEY_DELTA, Vector2.ZERO)
			viewport.accept_event()
		KeybindsHelperScript.ACTION_PAN_END:
			is_panning = false
			viewport.accept_event()

func _input(event: InputEvent) -> void:
	if not is_panning or not (event is InputEventMouseButton):
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_MIDDLE and not mouse_button.pressed:
		is_panning = false

func _zoom_at_viewport_position(factor: float, viewport_position: Vector2) -> void:
	var current_zoom := map_content.scale.x
	var next_zoom: float = clamp(current_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(current_zoom, next_zoom):
		return

	var map_point_before_zoom := (viewport_position - map_content.position) / current_zoom
	map_content.scale = Vector2(next_zoom, next_zoom)
	map_content.position = viewport_position - map_point_before_zoom * next_zoom
