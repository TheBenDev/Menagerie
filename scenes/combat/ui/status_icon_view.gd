## Control view that previews and renders a status icon from the shared status atlas.
@tool
class_name StatusIconView
extends Control

const DEFAULT_STATUS_ATLAS: Texture2D = preload("res://assets/ui/global/icons/statuses/statuses_13.png")
const HoverInfoPanelScript := preload("res://scenes/combat/ui/hover_info_panel.gd")

@export var status_atlas: Texture2D = DEFAULT_STATUS_ATLAS:
	set(value):
		status_atlas = value
		_refresh_icon()

@export var atlas_coords: Vector2i = Vector2i(0, 0):
	set(value):
		atlas_coords = value
		_refresh_icon()

@export var atlas_cell_size: Vector2i = Vector2i(200, 200):
	set(value):
		atlas_cell_size = value
		_refresh_icon()

@export var fallback_initial: String = "?":
	set(value):
		fallback_initial = value
		_refresh_icon()

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(52.0, 52.0)
	_refresh_icon()

func set_status_entry(entry: Dictionary) -> void:
	var display_name: String = str(entry.get("display_name", ""))
	fallback_initial = _status_initial(display_name)
	var status_data: Resource = entry.get("data", null) as Resource
	var description: String = str(entry.get("description", "")).strip_edges()
	if status_data != null:
		atlas_coords = _vector2i_value(status_data.get("icon_atlas_coords"), atlas_coords)
		atlas_cell_size = _vector2i_value(status_data.get("icon_atlas_cell_size"), atlas_cell_size)
		description = str(status_data.get("description")).strip_edges()
	else:
		atlas_coords = _vector2i_value(entry.get("icon_atlas_coords"), atlas_coords)
		atlas_cell_size = _vector2i_value(entry.get("icon_atlas_cell_size"), atlas_cell_size)

	var details: Array[String] = []
	var remaining_seconds: float = float(entry.get("remaining_seconds", 0.0))
	if remaining_seconds > 0.0:
		details.append("Remaining: %ss" % CombatTime.format_seconds(remaining_seconds))

	set_meta(HoverInfoPanelScript.META_TITLE, display_name)
	set_meta(HoverInfoPanelScript.META_DESCRIPTION, description)
	set_meta(HoverInfoPanelScript.META_DETAILS, details)

func clear_status_entry() -> void:
	atlas_coords = Vector2i(-1, -1)
	fallback_initial = ""
	queue_redraw()

func _refresh_icon() -> void:
	queue_redraw()

func _draw() -> void:
	if status_atlas != null and atlas_coords.x >= 0 and atlas_coords.y >= 0 and atlas_cell_size.x > 0 and atlas_cell_size.y > 0:
		var source_rect: Rect2 = Rect2(
			Vector2(float(atlas_coords.x * atlas_cell_size.x), float(atlas_coords.y * atlas_cell_size.y)),
			Vector2(float(atlas_cell_size.x), float(atlas_cell_size.y))
		)
		draw_texture_rect_region(status_atlas, Rect2(Vector2.ZERO, size), source_rect)
		return

	if fallback_initial.is_empty():
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var font_size: int = 18
	var text_size: Vector2 = font.get_string_size(fallback_initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_position: Vector2 = Vector2(
		(size.x - text_size.x) * 0.5,
		(size.y + text_size.y) * 0.5
	)
	draw_string(font, text_position, fallback_initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)

func _status_initial(display_name: String) -> String:
	if display_name.is_empty():
		return "?"

	return display_name.substr(0, 1).to_upper()

func _vector2i_value(value: Variant, default_value: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		var vector_value: Vector2 = value
		return Vector2i(int(vector_value.x), int(vector_value.y))

	return default_value
