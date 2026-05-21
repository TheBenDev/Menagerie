## Static helper for applying and drawing the shared numeric font for number spans inside UI text.
class_name NumberFont
extends RefCounted

const DEFAULT_NUMBER_FONT: Font = preload("res://assets/fonts/germania-one/GermaniaOne-Regular.ttf")
const NUMBER_CHARACTERS := "0123456789+-.,:%/#"

static func default_number_font() -> Font:
	return DEFAULT_NUMBER_FONT

static func apply_to_label(label: Label) -> void:
	if label == null:
		return

	var font := default_number_font()
	if font != null:
		label.add_theme_font_override("font", font)

static func apply_to_button(button: Button) -> void:
	if button == null:
		return

	var font := default_number_font()
	if font != null:
		button.add_theme_font_override("font", font)

static func mixed_width(text: String, text_font: Font, number_font: Font, font_size: int) -> float:
	var width := 0.0
	for span in _number_spans(text):
		var span_text := str(span.get("text", ""))
		var span_font := _font_for_span(bool(span.get("is_number", false)), text_font, number_font)
		if span_font == null:
			continue
		width += span_font.get_string_size(span_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

	return width

static func draw_mixed(
	canvas_item: CanvasItem,
	position: Vector2,
	text: String,
	text_font: Font,
	number_font: Font,
	font_size: int,
	color: Color
) -> float:
	var x := position.x
	for span in _number_spans(text):
		var span_text := str(span.get("text", ""))
		var span_font := _font_for_span(bool(span.get("is_number", false)), text_font, number_font)
		if span_font == null:
			continue

		var span_width := span_font.get_string_size(span_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		canvas_item.draw_string(span_font, Vector2(x, position.y), span_text, HORIZONTAL_ALIGNMENT_LEFT, span_width, font_size, color)
		x += span_width

	return x - position.x

static func draw_mixed_aligned(
	canvas_item: CanvasItem,
	rect_x: float,
	baseline_y: float,
	width: float,
	text: String,
	text_font: Font,
	number_font: Font,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var text_width := mixed_width(text, text_font, number_font, font_size)
	var x := rect_x
	match alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (width - text_width) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += width - text_width

	draw_mixed(canvas_item, Vector2(x, baseline_y), text, text_font, number_font, font_size, color)

static func set_rich_text(rich_label: RichTextLabel, text: String) -> void:
	if rich_label == null:
		return

	rich_label.text = ""
	rich_label.clear()
	append_rich_text(rich_label, text)

static func append_rich_text(rich_label: RichTextLabel, text: String) -> void:
	if rich_label == null:
		return

	var number_font := default_number_font()
	for span in _number_spans(text):
		var span_text := str(span.get("text", ""))
		if bool(span.get("is_number", false)) and number_font != null:
			rich_label.push_font(number_font)
			rich_label.add_text(span_text)
			rich_label.pop()
		else:
			rich_label.add_text(span_text)

static func _font_for_span(is_number: bool, text_font: Font, number_font: Font) -> Font:
	if is_number and number_font != null:
		return number_font

	return text_font

static func _number_spans(text: String) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	if text.is_empty():
		return spans

	var current_text := ""
	var current_is_number := false
	for index in range(text.length()):
		var character := text.substr(index, 1)
		var character_is_number := NUMBER_CHARACTERS.contains(character)
		if current_text.is_empty():
			current_text = character
			current_is_number = character_is_number
			continue

		if character_is_number == current_is_number:
			current_text += character
			continue

		spans.append({
			"text": current_text,
			"is_number": current_is_number,
		})
		current_text = character
		current_is_number = character_is_number

	spans.append({
		"text": current_text,
		"is_number": current_is_number,
	})
	return spans
