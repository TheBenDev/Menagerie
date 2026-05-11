## Fixed combat HUD panel that renders hover information from any registered Control.
class_name HoverInfoPanel
extends NinePatchRect

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")

const META_TITLE := &"hover_info_title"
const META_DESCRIPTION := &"hover_info_description"
const META_DETAILS := &"hover_info_details"
const META_TEXT := &"hover_info_text"

@export var info_text_path: NodePath = ^"PanelMargin/InfoText"

@onready var info_text_label: RichTextLabel = get_node(info_text_path) as RichTextLabel

func _ready() -> void:
	clear()

func bind_source(source: Control) -> void:
	if source == null:
		return

	var entered_callback: Callable = _on_source_mouse_entered.bind(source)
	if not source.mouse_entered.is_connected(entered_callback):
		source.mouse_entered.connect(entered_callback)

	if not source.mouse_exited.is_connected(clear):
		source.mouse_exited.connect(clear)

func set_source_info(source: Object, title: String, description: String = "", details: Array[String] = []) -> void:
	if source == null:
		return

	source.set_meta(META_TITLE, title)
	source.set_meta(META_DESCRIPTION, description)
	source.set_meta(META_DETAILS, details)

func show_for_source(source: Object) -> void:
	if source == null:
		clear()
		return

	var full_text: String = str(source.get_meta(META_TEXT, "")).strip_edges()
	if full_text.is_empty():
		full_text = _compose_source_text(source)

	show_text(full_text)

func show_text(info_text: String) -> void:
	NumberFontHelper.set_rich_text(info_text_label, info_text.strip_edges())

func clear() -> void:
	NumberFontHelper.set_rich_text(info_text_label, "")

func _compose_source_text(source: Object) -> String:
	var lines: Array[String] = []
	var title: String = str(source.get_meta(META_TITLE, "")).strip_edges()
	var description: String = str(source.get_meta(META_DESCRIPTION, "")).strip_edges()

	if not title.is_empty():
		lines.append(title)
	if not description.is_empty():
		lines.append(description)

	var details_value: Variant = source.get_meta(META_DETAILS, [])
	if details_value is Array:
		for raw_detail: Variant in details_value:
			var detail: String = str(raw_detail).strip_edges()
			if not detail.is_empty():
				lines.append(detail)
	elif details_value is PackedStringArray:
		for detail in details_value:
			var detail_text: String = str(detail).strip_edges()
			if not detail_text.is_empty():
				lines.append(detail_text)

	return "\n".join(lines)

func _on_source_mouse_entered(source: Control) -> void:
	show_for_source(source)
