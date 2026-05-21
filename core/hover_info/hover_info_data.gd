## Shared payload used by hoverable resources and controls to populate tooltip panels.
class_name HoverInfoData
extends Resource

const HoverInfoFieldScript := preload("res://core/hover_info/hover_info_field.gd")
const HoverInfoTextSegmentScript := preload("res://core/hover_info/hover_info_text_segment.gd")

@export var icon: Texture2D = null
@export var title: String = ""
@export var subtitle: String = ""
@export var header_right_text: String = ""
@export var header_right_icon: Texture2D = null
@export_multiline var description: String = ""
@export var description_segments: Array[Resource] = []
@export var footer: String = ""
@export var fields: Array[Resource] = []
@export var keyword_ids: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var rarity: StringName = &""
@export var panel_style: StringName = &"default"
@export var use_accent_color: bool = false
@export var accent_color: Color = Color.WHITE

func has_content() -> bool:
	return (
		not title.strip_edges().is_empty()
		or not subtitle.strip_edges().is_empty()
		or not header_right_text.strip_edges().is_empty()
		or header_right_icon != null
		or not description.strip_edges().is_empty()
		or not description_segments.is_empty()
		or not footer.strip_edges().is_empty()
		or not fields.is_empty()
	)

func add_field(label: String, value: String, field_icon: Texture2D = null) -> void:
	var trimmed_value := value.strip_edges()
	if trimmed_value.is_empty():
		return

	fields.append(HoverInfoFieldScript.from_values(label, trimmed_value, field_icon))

func add_description_text(text: String, text_color: Color = Color.WHITE, use_color: bool = false) -> void:
	if text.is_empty():
		return

	description_segments.append(HoverInfoTextSegmentScript.from_text(text, text_color, use_color))

func add_description_icon(description_icon: Texture2D, icon_size: Vector2 = Vector2(16.0, 16.0)) -> void:
	if description_icon == null:
		return

	description_segments.append(HoverInfoTextSegmentScript.from_icon(description_icon, icon_size))
