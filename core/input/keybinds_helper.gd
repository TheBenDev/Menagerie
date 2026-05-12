## Shared input helper that translates raw keybind and mouse events into semantic view navigation actions.
class_name KeybindsHelper
extends RefCounted

const NONE := &""
const ZOOM_IN := &"zoom_in"
const ZOOM_OUT := &"zoom_out"
const PAN_START := &"pan_start"
const PAN_MOVE := &"pan_move"
const PAN_END := &"pan_end"

const ACTION := "action"
const POSITION := "position"
const DELTA := "delta"

static func process_map_navigation_event(event: InputEvent, is_panning: bool) -> Dictionary:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			return {
				ACTION: ZOOM_IN,
				POSITION: mouse_button.position,
			}
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			return {
				ACTION: ZOOM_OUT,
				POSITION: mouse_button.position,
			}
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			return {
				ACTION: PAN_START if mouse_button.pressed else PAN_END,
				POSITION: mouse_button.position,
			}

	if event is InputEventMouseMotion and is_panning:
		var mouse_motion := event as InputEventMouseMotion
		return {
			ACTION: PAN_MOVE,
			POSITION: mouse_motion.position,
			DELTA: mouse_motion.relative,
		}

	return {
		ACTION: NONE,
	}
