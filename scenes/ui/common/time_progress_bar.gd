## Custom control that draws the run timer fill inside its authored frame proportions.
class_name TimeProgressBar
extends Control

@export var max_value: float = 300.0
@export var value: float = 300.0
@export var fill_color: Color = Color(0.95, 0.66, 0.18, 1.0)
@export var fill_highlight_color: Color = Color(1.0, 0.84, 0.34, 1.0)
@export var empty_fill_color: Color = Color(0.08, 0.022, 0.015, 0.82)

const FILL_LEFT_RATIO := 0.150
const FILL_TOP_RATIO := 0.43
const FILL_RIGHT_RATIO := 0.915
const FILL_BOTTOM_RATIO := 0.785
const FILL_LEFT_EXTRA_PIXELS := 25.0

func _ready() -> void:
	custom_minimum_size = Vector2(960, 90)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	queue_redraw()

func set_timer_values(new_value: float, new_max_value: float) -> void:
	max_value = maxf(new_max_value, 1.0)
	value = clampf(new_value, 0.0, max_value)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var fill_rect := _fill_rect()
	var percent: float = clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	draw_rect(fill_rect, empty_fill_color, true)

	if percent <= 0.0:
		return

	var active_fill := Rect2(fill_rect.position, Vector2(fill_rect.size.x * percent, fill_rect.size.y))
	draw_rect(active_fill, fill_color, true)
	draw_rect(
		Rect2(active_fill.position, Vector2(active_fill.size.x, maxf(active_fill.size.y * 0.32, 1.0))),
		fill_highlight_color,
		true
	)

func _fill_rect() -> Rect2:
	var left: float = maxf(size.x * FILL_LEFT_RATIO - FILL_LEFT_EXTRA_PIXELS, 0.0)
	var top: float = size.y * FILL_TOP_RATIO
	var right: float = size.x * FILL_RIGHT_RATIO
	var bottom: float = size.y * FILL_BOTTOM_RATIO
	return Rect2(Vector2(left, top), Vector2(maxf(right - left, 0.0), maxf(bottom - top, 0.0)))

func _on_resized() -> void:
	queue_redraw()
