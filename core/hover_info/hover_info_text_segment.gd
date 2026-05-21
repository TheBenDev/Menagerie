## Rich text segment used by hover tooltip bodies for colored text and inline icons.
class_name HoverInfoTextSegment
extends Resource

@export var text: String = ""
@export var use_color: bool = false
@export var color: Color = Color.WHITE
@export var icon: Texture2D = null
@export var icon_size: Vector2 = Vector2(16.0, 16.0)

static func from_text(new_text: String, text_color: Color = Color.WHITE, should_use_color: bool = false) -> Resource:
	var segment := HoverInfoTextSegment.new()
	segment.text = new_text
	segment.color = text_color
	segment.use_color = should_use_color
	return segment

static func from_icon(new_icon: Texture2D, new_icon_size: Vector2 = Vector2(16.0, 16.0)) -> Resource:
	var segment := HoverInfoTextSegment.new()
	segment.icon = new_icon
	segment.icon_size = new_icon_size
	return segment
