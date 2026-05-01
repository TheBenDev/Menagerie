## Shared input helper that translates raw keybind and mouse events into semantic view navigation actions.
class_name KeybindsHelper
extends RefCounted

const ACTION_NONE := &""
const ACTION_ZOOM_IN := &"zoom_in"
const ACTION_ZOOM_OUT := &"zoom_out"
const ACTION_PAN_START := &"pan_start"
const ACTION_PAN_MOVE := &"pan_move"
const ACTION_PAN_END := &"pan_end"

const KEY_ACTION := "action"
const KEY_POSITION := "position"
const KEY_DELTA := "delta"

static func process_map_navigation_event(event: InputEvent, is_panning: bool) -> Dictionary:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			return {
				KEY_ACTION: ACTION_ZOOM_IN,
				KEY_POSITION: mouse_button.position,
			}
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			return {
				KEY_ACTION: ACTION_ZOOM_OUT,
				KEY_POSITION: mouse_button.position,
			}
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			return {
				KEY_ACTION: ACTION_PAN_START if mouse_button.pressed else ACTION_PAN_END,
				KEY_POSITION: mouse_button.position,
			}

	if event is InputEventMouseMotion and is_panning:
		var mouse_motion := event as InputEventMouseMotion
		return {
			KEY_ACTION: ACTION_PAN_MOVE,
			KEY_POSITION: mouse_motion.position,
			KEY_DELTA: mouse_motion.relative,
		}

	return {
		KEY_ACTION: ACTION_NONE,
	}
