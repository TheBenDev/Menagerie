## Custom control that draws a labeled resource meter with optional reference value and bonus text.
extends Control

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")

@export var resource_name: String = "Resource"
@export var current_value: int = 0
@export var reference_value: int = 1
@export var display_reference_value: bool = true
@export var low_color: Color = Color(0.86, 0.16, 0.12)
@export var high_color: Color = Color(0.16, 0.72, 0.26)
@export var over_reference_color: Color = Color.TRANSPARENT
@export var background_color: Color = Color(0.075, 0.08, 0.085)
@export var border_color: Color = Color(0.86, 0.88, 0.9)
@export var text_color: Color = Color.WHITE
@export var bonus_label: String = ""
@export var bonus_value: int = 0
@export var bonus_text_color: Color = Color(0.34, 0.64, 1.0)
@export var fill_start_value: int = 0
@export var draw_text: bool = true

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func configure(
	new_resource_name: String,
	new_display_reference_value: bool,
	new_low_color: Color,
	new_high_color: Color,
	new_over_reference_color: Color = Color.TRANSPARENT,
	new_bonus_label: String = ""
) -> void:
	resource_name = new_resource_name
	display_reference_value = new_display_reference_value
	low_color = new_low_color
	high_color = new_high_color
	over_reference_color = new_over_reference_color
	bonus_label = new_bonus_label
	queue_redraw()

func configure_from_config(config: Resource) -> void:
	if config == null:
		return

	configure(
		str(config.get("label")),
		bool(config.get("display_reference_value")),
		config.get("low_color") as Color,
		config.get("high_color") as Color,
		config.get("over_reference_color") as Color,
		str(config.get("bonus_label"))
	)

	var configured_reference: int = int(config.get("reference_value"))
	if configured_reference > 0:
		reference_value = configured_reference

func set_values(new_current_value: int, new_reference_value: int = -1, new_bonus_value: int = 0) -> void:
	current_value = max(new_current_value, 0)
	if new_reference_value > 0:
		reference_value = new_reference_value
	bonus_value = max(new_bonus_value, 0)
	queue_redraw()

func set_segment_values(new_start_value: int, new_current_value: int, new_reference_value: int = -1) -> void:
	fill_start_value = max(new_start_value, 0)
	set_values(new_current_value, new_reference_value, 0)

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var reference: int = max(reference_value, 1)
	var start_percent: float = clamp(float(fill_start_value) / float(reference), 0.0, 1.0)
	var percent: float = clamp(float(current_value) / float(reference), 0.0, 1.0)
	var fill_color: Color = _fill_color(percent)
	var fill_rect: Rect2 = Rect2(
		Vector2(size.x * start_percent, 0.0),
		Vector2(size.x * max(percent - start_percent, 0.0), size.y)
	)

	if background_color.a > 0.0:
		draw_rect(rect, background_color, true)
	if fill_rect.size.x > 0.0 and fill_color.a > 0.0:
		draw_rect(fill_rect, fill_color, true)
	if border_color.a > 0.0:
		draw_rect(rect, border_color, false, 1.0)

	if draw_text:
		_draw_text()

func _fill_color(percent: float) -> Color:
	if current_value > reference_value and over_reference_color.a > 0.0:
		return over_reference_color

	return low_color.lerp(high_color, percent)

func _draw_text() -> void:
	var font := get_theme_default_font()
	var number_font := NumberFontHelper.default_number_font()
	var font_size := get_theme_default_font_size()
	var primary_text := _primary_text()
	var bonus_text := _bonus_text()
	var primary_width := NumberFontHelper.mixed_width(primary_text, font, number_font, font_size)
	var bonus_width := NumberFontHelper.mixed_width(bonus_text, font, number_font, font_size)
	var total_width := primary_width + bonus_width
	var baseline_y: float = floor((size.y + font_size) * 0.5) - 2.0
	var start_x: float = max((size.x - total_width) * 0.5, 4.0)

	NumberFontHelper.draw_mixed(self, Vector2(start_x, baseline_y), primary_text, font, number_font, font_size, text_color)
	if not bonus_text.is_empty():
		NumberFontHelper.draw_mixed(self, Vector2(start_x + primary_width, baseline_y), bonus_text, font, number_font, font_size, bonus_text_color)

func _primary_text() -> String:
	if display_reference_value:
		return "%s %s/%s" % [resource_name, current_value, reference_value]

	return "%s %s" % [resource_name, current_value]

func _bonus_text() -> String:
	if bonus_value <= 0 or bonus_label.is_empty():
		return ""

	return "  +%s %s" % [bonus_value, bonus_label]
