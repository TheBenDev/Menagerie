class_name CombatTime
extends RefCounted

const TIME_STEP_SECONDS := 0.1
const TIME_EPSILON := 0.0001

static func snap_seconds(value: float) -> float:
	if value <= 0.0:
		return 0.0

	return max(snapped(value, TIME_STEP_SECONDS), TIME_STEP_SECONDS)

static func snap_absolute_time(value: float) -> float:
	return snapped(max(value, 0.0), TIME_STEP_SECONDS)

static func is_due(resolve_time: float, current_time: float) -> bool:
	return resolve_time <= current_time + TIME_EPSILON

static func format_seconds(value: float) -> String:
	var snapped_value := snap_seconds(value)
	if is_equal_approx(snapped_value, roundf(snapped_value)):
		return str(int(roundi(snapped_value)))

	return "%.1f" % snapped_value
