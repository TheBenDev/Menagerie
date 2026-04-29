class_name TimelineView
extends Control

const NumberFontHelper := preload("res://scripts/ui/common/number_font.gd")

var current_time: float = 0.0
var auto_display_time: float = 0.0
var display_time: float = 0.0
var visible_seconds: int = 10
var markers: Array[Dictionary] = []
var is_advancing: bool = false
var is_paused: bool = false
var time_scale: float = 1.0
var scroll_offset_seconds: float = 0.0
var is_dragging_timeline: bool = false

const MIN_VIEW_START_TIME := 0.0
const WHEEL_SCROLL_SECONDS := 1.0
const FUTURE_SCROLL_PADDING_SECONDS := 2.0
const EDGE_TIME_EPSILON := 0.001

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(0, 128)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func set_timeline_state(
	new_current_time: float,
	new_markers: Array[Dictionary],
	new_is_advancing: bool,
	new_time_scale: float,
	new_is_paused: bool = false
) -> void:
	current_time = new_current_time
	markers = new_markers
	is_advancing = new_is_advancing
	is_paused = new_is_paused
	time_scale = max(new_time_scale, 0.01)
	if auto_display_time < current_time:
		auto_display_time = current_time
	if not is_advancing and not is_paused:
		auto_display_time = current_time
	_update_display_time()
	queue_redraw()

func _process(delta: float) -> void:
	if is_advancing and not is_paused:
		var next_tick_time: float = current_time + CombatTime.TIME_STEP_SECONDS
		auto_display_time = min(auto_display_time + delta * time_scale, next_tick_time)
	elif not is_paused and not is_equal_approx(auto_display_time, current_time):
		auto_display_time = current_time

	_update_display_time()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_shift_view_time(-WHEEL_SCROLL_SECONDS)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_shift_view_time(WHEEL_SCROLL_SECONDS)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and event.pressed:
				_reset_view_time()
				accept_event()
			else:
				is_dragging_timeline = event.pressed
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_reset_view_time()
			accept_event()
	elif event is InputEventMouseMotion and is_dragging_timeline:
		var track_width: float = _track_width()
		var seconds_delta: float = -event.relative.x / track_width * float(visible_seconds)
		_shift_view_time(seconds_delta)
		accept_event()

func _shift_view_time(delta_seconds: float) -> void:
	var desired_display_time := display_time + delta_seconds
	display_time = _clamp_display_time(desired_display_time)
	scroll_offset_seconds = display_time - auto_display_time
	queue_redraw()

func _reset_view_time() -> void:
	scroll_offset_seconds = 0.0
	_update_display_time()
	queue_redraw()

func _update_display_time() -> void:
	display_time = _clamp_display_time(auto_display_time + scroll_offset_seconds)
	scroll_offset_seconds = display_time - auto_display_time

func _clamp_display_time(value: float) -> float:
	return clamp(value, MIN_VIEW_START_TIME, _max_view_start_time())

func _max_view_start_time() -> float:
	var latest_visible_time := current_time + float(visible_seconds)
	for marker in markers:
		latest_visible_time = max(latest_visible_time, float(marker.get("time", 0.0)) + FUTURE_SCROLL_PADDING_SECONDS)

	return max(MIN_VIEW_START_TIME, latest_visible_time - float(visible_seconds))

func _track_width() -> float:
	return max(size.x - 68.0, 1.0)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var background_color := Color(0.105, 0.11, 0.12)
	var border_color := Color(0.28, 0.29, 0.31)
	draw_rect(rect, background_color, true)

	var font := get_theme_default_font()
	var number_font := NumberFontHelper.default_number_font()
	var font_size := get_theme_default_font_size()
	var left := 48.0
	var right := 20.0
	var track_start := left
	var track_end := size.x - right
	var top_number_y := 24.0
	var track_y := 46.0
	var marker_base_y := 78.0
	var marker_stack_gap := 28.0
	var track_width: float = max(track_end - track_start, 1.0)
	var line_color := Color(0.72, 0.72, 0.72)
	var muted_text := Color(0.76, 0.78, 0.82)
	var tick_label_width := 36.0
	var action_label_width := 96.0
	var marker_half_size := 13.0

	var first_tenth := int(floor(display_time / CombatTime.TIME_STEP_SECONDS)) - 1
	var last_tenth := int(ceil((display_time + float(visible_seconds)) / CombatTime.TIME_STEP_SECONDS)) + 1
	var first_second := int(floor(display_time)) - 1
	var last_second := int(floor(display_time)) + visible_seconds + 2

	draw_line(Vector2(track_start, track_y), Vector2(track_end, track_y), line_color, 2.0)
	draw_line(Vector2(track_start, marker_base_y + marker_stack_gap + 17.0), Vector2(track_end, marker_base_y + marker_stack_gap + 17.0), line_color, 2.0)

	for tenth in range(first_tenth, last_tenth + 1):
		var tick_time: float = float(tenth) * CombatTime.TIME_STEP_SECONDS
		var ratio: float = (tick_time - display_time) / float(visible_seconds)
		var x: float = track_start + ratio * track_width
		if x < track_start or x > track_end:
			continue

		var tenth_in_second := posmod(tenth, 10)
		if tenth_in_second == 0:
			draw_line(Vector2(x, track_y - 7.0), Vector2(x, track_y + 7.0), Color(0.50, 0.51, 0.54), 1.0)
		elif tenth_in_second == 5:
			draw_line(Vector2(x, track_y - 4.0), Vector2(x, track_y + 4.0), Color(0.38, 0.39, 0.42), 1.0)
		else:
			draw_line(Vector2(x, track_y - 2.0), Vector2(x, track_y + 2.0), Color(0.28, 0.29, 0.32), 1.0)

	for second in range(first_second, last_second + 1):
		var ratio := (float(second) - display_time) / float(visible_seconds)
		var x: float = track_start + ratio * track_width
		var tick_label_x: float = x - tick_label_width * 0.5
		if not _range_intersects(tick_label_x, tick_label_x + tick_label_width, track_start, track_end):
			continue
		NumberFontHelper.draw_mixed_aligned(self, tick_label_x, top_number_y, tick_label_width, str(second), font, number_font, font_size, muted_text, HORIZONTAL_ALIGNMENT_CENTER)

	var visible_markers := _visible_markers()
	var stack_counts: Dictionary = {}
	for marker in visible_markers:
		var finish_time := float(marker.get("time", 0.0))
		var marker_ratio := (finish_time - display_time) / float(visible_seconds)
		var marker_x := track_start + marker_ratio * track_width
		var stack_key := str(CombatTime.snap_absolute_time(finish_time))
		var stack_index := int(stack_counts.get(stack_key, 0))
		stack_counts[stack_key] = stack_index + 1
		var marker_y: float = marker_base_y + float(stack_index % 2) * marker_stack_gap
		var color := _marker_color(marker)
		var initial := str(marker.get("initial", "?"))
		var action_name := str(marker.get("action", "Action"))
		var marker_rect := Rect2(Vector2(marker_x - marker_half_size, marker_y - marker_half_size), Vector2(26.0, 26.0))
		var action_label_x: float = marker_x - action_label_width * 0.5

		draw_rect(marker_rect, color, true)
		draw_rect(marker_rect, Color(0.95, 0.96, 0.98), false, 2.0)
		NumberFontHelper.draw_mixed_aligned(self, marker_x - 10.0, marker_y + 6.0, 20.0, initial, font, number_font, font_size, Color(0.06, 0.065, 0.07), HORIZONTAL_ALIGNMENT_CENTER)
		NumberFontHelper.draw_mixed_aligned(self, action_label_x, marker_y - 20.0, action_label_width, action_name, font, number_font, max(font_size - 3, 10), muted_text, HORIZONTAL_ALIGNMENT_CENTER)

	_draw_edge_masks(track_start, track_end, background_color)
	_draw_playhead(track_start, track_end, track_width, track_y, marker_base_y + marker_stack_gap + 19.0)
	draw_rect(rect, border_color, false, 1.0)

func _visible_markers() -> Array[Dictionary]:
	var visible_marker_entries: Array[Dictionary] = []
	var view_start := display_time - EDGE_TIME_EPSILON
	var view_end := display_time + float(visible_seconds) + EDGE_TIME_EPSILON
	for marker in markers:
		var marker_time := float(marker.get("time", 0.0))
		if marker_time < view_start or marker_time > view_end:
			continue
		visible_marker_entries.append(marker)

	visible_marker_entries.sort_custom(_sort_markers)
	return visible_marker_entries

func _draw_edge_masks(track_start: float, track_end: float, background_color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(track_start, size.y)), background_color, true)
	draw_rect(Rect2(Vector2(track_end, 0.0), Vector2(max(size.x - track_end, 0.0), size.y)), background_color, true)

func _draw_playhead(track_start: float, track_end: float, track_width: float, top_y: float, bottom_y: float) -> void:
	var playhead_ratio := (auto_display_time - display_time) / float(visible_seconds)
	if playhead_ratio < 0.0 or playhead_ratio > 1.0:
		return

	var playhead_x: float = clamp(track_start + playhead_ratio * track_width, track_start, track_end)
	var color := Color(1.0, 0.78, 0.28)
	draw_line(Vector2(playhead_x, top_y - 10.0), Vector2(playhead_x, bottom_y), color, 2.0)
	draw_circle(Vector2(playhead_x, top_y - 12.0), 5.0, color)

func _range_intersects(start_a: float, end_a: float, start_b: float, end_b: float) -> bool:
	return start_a <= end_b and end_a >= start_b

func _marker_color(marker: Dictionary) -> Color:
	var color: Color = marker.get("color", Color.WHITE)
	if str(marker.get("status", "")) == QueuedAction.STATUS_RESOLVED:
		return color.lerp(Color(0.55, 0.56, 0.58), 0.45)

	return color

func _sort_markers(a: Dictionary, b: Dictionary) -> bool:
	var a_time := float(a.get("time", 0.0))
	var b_time := float(b.get("time", 0.0))
	if not is_equal_approx(a_time, b_time):
		return a_time < b_time

	return int(a.get("order", 0)) < int(b.get("order", 0))
