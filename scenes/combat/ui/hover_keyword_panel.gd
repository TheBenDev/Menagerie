## Compact side panel for explaining hover keyword status resources.
class_name HoverKeywordPanel
extends PanelContainer

const NumberFontHelper := preload("res://scenes/ui/common/number_font.gd")

@export var title_path: NodePath = ^"Margin/Layout/KeywordTitle"
@export var description_path: NodePath = ^"Margin/Layout/KeywordDescription"

@onready var title_label: Label = get_node_or_null(title_path) as Label
@onready var description_label: RichTextLabel = get_node_or_null(description_path) as RichTextLabel

var base_panel_stylebox: StyleBox = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_panel_stylebox = get_theme_stylebox("panel").duplicate()
	NumberFontHelper.apply_to_label(title_label)
	if description_label != null:
		description_label.fit_content = true
		description_label.scroll_active = false
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_keyword_info(info) -> void:
	if info == null:
		visible = false
		return

	visible = true
	if title_label != null:
		title_label.text = info.title.strip_edges()
		_apply_title_color(info)
	if description_label != null:
		NumberFontHelper.set_rich_text(description_label, info.description.strip_edges())
	_apply_panel_accent(info)
	reset_size()

func _apply_title_color(info) -> void:
	if title_label == null:
		return

	if bool(info.get("use_accent_color")):
		var accent_color: Color = info.get("accent_color")
		title_label.add_theme_color_override("font_color", accent_color)
	else:
		title_label.remove_theme_color_override("font_color")

func _apply_panel_accent(info) -> void:
	if base_panel_stylebox == null:
		return

	var next_stylebox := base_panel_stylebox.duplicate()
	if bool(info.get("use_accent_color")) and next_stylebox is StyleBoxFlat:
		var flat_stylebox := next_stylebox as StyleBoxFlat
		var accent_color: Color = info.get("accent_color")
		accent_color.a = 0.95
		flat_stylebox.border_color = accent_color

	add_theme_stylebox_override("panel", next_stylebox)
