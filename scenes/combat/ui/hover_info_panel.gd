## Scene-backed main hover tooltip panel populated from HoverInfoData.
class_name HoverInfoPanel
extends PanelContainer

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")

@export var icon_path: NodePath = ^"Margin/Layout/HeaderRow/Icon"
@export var title_path: NodePath = ^"Margin/Layout/HeaderRow/HeaderText/Title"
@export var subtitle_path: NodePath = ^"Margin/Layout/HeaderRow/HeaderText/Subtitle"
@export var header_right_path: NodePath = ^"Margin/Layout/HeaderRow/HeaderRightText"
@export var body_path: NodePath = ^"Margin/Layout/BodyText"
@export var field_list_path: NodePath = ^"Margin/Layout/FieldList"
@export var footer_path: NodePath = ^"Margin/Layout/FooterText"
@export var extra_info_path: NodePath = ^"Margin/Layout/ExtraInfoContainer"

@onready var icon_texture: TextureRect = get_node_or_null(icon_path) as TextureRect
@onready var title_label: Label = get_node_or_null(title_path) as Label
@onready var subtitle_label: Label = get_node_or_null(subtitle_path) as Label
@onready var header_right_label: Label = get_node_or_null(header_right_path) as Label
@onready var body_text: RichTextLabel = get_node_or_null(body_path) as RichTextLabel
@onready var field_list: VBoxContainer = get_node_or_null(field_list_path) as VBoxContainer
@onready var footer_text: RichTextLabel = get_node_or_null(footer_path) as RichTextLabel
@onready var extra_info_container: Control = get_node_or_null(extra_info_path) as Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_rich_text(body_text)
	_configure_rich_text(footer_text)
	_apply_number_fonts()

func set_hover_info(info) -> void:
	_clear_fields()
	if info == null:
		visible = false
		return

	visible = true
	_set_icon(info.icon)
	_set_label_text(title_label, info.title)
	_set_label_text(subtitle_label, info.subtitle)
	_set_label_text(header_right_label, info.header_right_text)
	_set_rich_content(body_text, info.description, info.description_segments)
	_set_rich_text(footer_text, info.footer)
	_populate_fields(info.fields)

	if extra_info_container != null:
		extra_info_container.visible = extra_info_container.get_child_count() > 0

	reset_size()

func _set_icon(texture: Texture2D) -> void:
	if icon_texture == null:
		return

	icon_texture.texture = texture
	icon_texture.visible = texture != null

func _set_label_text(label: Label, text: String) -> void:
	if label == null:
		return

	var trimmed_text := text.strip_edges()
	label.text = trimmed_text
	label.visible = not trimmed_text.is_empty()

func _set_rich_text(label: RichTextLabel, text: String) -> void:
	if label == null:
		return

	var trimmed_text := text.strip_edges()
	NumberFontHelper.set_rich_text(label, trimmed_text)
	label.visible = not trimmed_text.is_empty()

func _set_rich_content(label: RichTextLabel, text: String, segments: Array) -> void:
	if label == null:
		return

	if segments.is_empty():
		_set_rich_text(label, text)
		return

	label.text = ""
	label.clear()
	for segment in segments:
		_append_rich_segment(label, segment)
	label.visible = true

func _append_rich_segment(label: RichTextLabel, segment) -> void:
	if segment == null:
		return

	var icon := segment.get("icon") as Texture2D
	if icon != null:
		var icon_size: Vector2 = segment.get("icon_size")
		label.add_image(icon, int(max(icon_size.x, 1.0)), int(max(icon_size.y, 1.0)))

	var text := str(segment.get("text"))
	if text.is_empty():
		return

	if bool(segment.get("use_color")):
		var text_color: Color = segment.get("color")
		label.push_color(text_color)
		NumberFontHelper.append_rich_text(label, text)
		label.pop()
	else:
		NumberFontHelper.append_rich_text(label, text)

func _populate_fields(fields: Array) -> void:
	if field_list == null:
		return

	for field in fields:
		if field == null:
			continue

		var row := _field_row(field)
		if row != null:
			field_list.add_child(row)

	field_list.visible = field_list.get_child_count() > 0

func _field_row(field) -> Control:
	var label_text: String = str(field.get("label")).strip_edges()
	var value_text: String = str(field.get("value")).strip_edges()
	if label_text.is_empty() and value_text.is_empty():
		return null

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var field_icon := field.get("icon") as Texture2D
	if field_icon != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18.0, 18.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = field_icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	if not label_text.is_empty():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.theme_type_variation = &"CombatTooltipFieldLabel"
		label.text = "%s:" % label_text
		label.custom_minimum_size = Vector2(104.0, 0.0)
		NumberFontHelper.apply_to_label(label)
		row.add_child(label)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.theme_type_variation = &"CombatTooltipFieldValue"
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	NumberFontHelper.apply_to_label(value)
	row.add_child(value)
	return row

func _clear_fields() -> void:
	if field_list == null:
		return

	for child in field_list.get_children():
		child.queue_free()
	field_list.visible = false

func _apply_number_fonts() -> void:
	NumberFontHelper.apply_to_label(title_label)
	NumberFontHelper.apply_to_label(subtitle_label)
	NumberFontHelper.apply_to_label(header_right_label)

func _configure_rich_text(label: RichTextLabel) -> void:
	if label == null:
		return

	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
