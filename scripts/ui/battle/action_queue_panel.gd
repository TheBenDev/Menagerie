## Panel that renders pending and resolved combat actions in queue order for the battle HUD.
class_name ActionQueuePanel
extends PanelContainer

const NumberFontHelper := preload("res://scripts/ui/common/number_font.gd")

@onready var queue_log: RichTextLabel = $PanelMargin/ActionQueue/QueueLog

func refresh(action_queue: Array[QueuedAction]) -> void:
	var lines: Array[String] = []
	lines.append("Pending")

	var pending_entries := _pending_queue_entries(action_queue)
	if pending_entries.is_empty():
		lines.append("  None")
	else:
		for entry in pending_entries:
			lines.append("  %ss  %s: %s" % [
				CombatTime.format_seconds(entry.resolve_time),
				entry.actor.display_name,
				entry.action.display_name,
			])

	lines.append("")
	lines.append("History")

	var history_entries := _history_queue_entries(action_queue)
	if history_entries.is_empty():
		lines.append("  None")
	else:
		for entry in history_entries:
			lines.append(_history_line(entry))

	NumberFontHelper.set_rich_text(queue_log, "\n".join(lines))

func _pending_queue_entries(action_queue: Array[QueuedAction]) -> Array[QueuedAction]:
	var entries: Array[QueuedAction] = []
	for entry in action_queue:
		if entry.status == QueuedAction.STATUS_PENDING:
			entries.append(entry)
	entries.sort_custom(_sort_queue_pending)
	return entries

func _history_queue_entries(action_queue: Array[QueuedAction]) -> Array[QueuedAction]:
	var entries: Array[QueuedAction] = []
	for entry in action_queue:
		if entry.status != QueuedAction.STATUS_PENDING:
			entries.append(entry)
	entries.sort_custom(_sort_queue_history)
	return entries

func _history_line(entry: QueuedAction) -> String:
	var detail := ""
	if entry.status == QueuedAction.STATUS_RESOLVED:
		detail = "resolved"
		if not entry.tie_rolls.is_empty():
			detail += " roll %s" % entry.tie_rolls.back()
	else:
		detail = entry.status

	var order_text := str(entry.resolution_order) if entry.resolution_order > 0 else "-"
	var entry_time := entry.resolved_time if entry.resolved_time >= 0.0 else entry.resolve_time
	return "  #%s %ss  %s: %s (%s)" % [
		order_text,
		CombatTime.format_seconds(entry_time),
		entry.actor.display_name,
		entry.action.display_name,
		detail,
	]

func _sort_queue_pending(a: QueuedAction, b: QueuedAction) -> bool:
	if not is_equal_approx(a.resolve_time, b.resolve_time):
		return a.resolve_time < b.resolve_time
	return a.id < b.id

func _sort_queue_history(a: QueuedAction, b: QueuedAction) -> bool:
	return a.id > b.id
