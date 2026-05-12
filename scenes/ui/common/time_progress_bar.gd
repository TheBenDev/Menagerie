## Custom control that draws the run timer fill inside this node's bounds.
class_name TimeProgressBar
extends Control

@export var max_value: float = 300.0
@export var value: float = 300.0
@export var fill_color: Color = Color(0.95, 0.66, 0.18, 1.0)
@export var fill_highlight_color: Color = Color(1.0, 0.84, 0.34, 1.0)
@export var empty_fill_color: Color = Color(0.08, 0.022, 0.015, 0.82)

func _ready() -> void:
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

	var fill_rect: Rect2 = Rect2(Vector2.ZERO, size)
	var percent: float = clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	draw_rect(fill_rect, empty_fill_color, true)

	if percent <= 0.0:
		return

	var active_fill: Rect2 = Rect2(fill_rect.position, Vector2(fill_rect.size.x * percent, fill_rect.size.y))
	draw_rect(active_fill, fill_color, true)
	draw_rect(
		Rect2(active_fill.position, Vector2(active_fill.size.x, maxf(active_fill.size.y * 0.32, 1.0))),
		fill_highlight_color,
		true
	)

func _on_resized() -> void:
	queue_redraw()
