## HUD panel for one combatant, including name, placeholder art, health, extra resources, and statuses.
class_name CombatantPanel
extends PanelContainer

const ResourceBarScript := preload("res://scenes/ui/common/resource_bar.gd")

@onready var name_label: Label = $PanelMargin/PanelLayout/NameLabel
@onready var placeholder_art: ColorRect = $PanelMargin/PanelLayout/PlaceHolderArt
@onready var status_label: RichTextLabel = $PanelMargin/PanelLayout/PlaceHolderArt/StatusLabel
@onready var health_bar: ResourceBarScript = $PanelMargin/PanelLayout/HealthBar
@onready var resource_bars: VBoxContainer = $PanelMargin/PanelLayout/ResourceBars

var combatant: Combatant = null
var extra_bar_entries: Array[Dictionary] = []
var spacer_nodes: Array[Control] = []

func setup(new_combatant: Combatant) -> void:
	combatant = new_combatant
	_apply_profile()
	refresh()

func refresh() -> void:
	if combatant == null:
		return

	name_label.text = combatant.display_name
	_update_bar(health_bar, combatant.get_health_bar_config())
	_update_status_label()

	for entry in extra_bar_entries:
		var bar := entry.get("bar") as ResourceBarScript
		var config := entry.get("config") as Resource
		_update_bar(bar, config)

func get_extra_resource_count() -> int:
	return extra_bar_entries.size()

func set_resource_slot_count(slot_count: int) -> void:
	_clear_spacers()

	var spacer_count: int = max(slot_count - extra_bar_entries.size(), 0)
	for _index in range(spacer_count):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 28)
		resource_bars.add_child(spacer)
		spacer_nodes.append(spacer)

func _apply_profile() -> void:
	if combatant == null:
		return

	name_label.text = combatant.display_name
	placeholder_art.color = combatant.get_placeholder_color()
	health_bar.configure_from_config(combatant.get_health_bar_config())
	_build_extra_resource_bars()
	_update_status_label()

func _build_extra_resource_bars() -> void:
	_clear_extra_resource_bars()

	for config in combatant.get_resource_bar_configs():
		var bar := ResourceBarScript.new() as ResourceBarScript
		bar.configure_from_config(config)
		resource_bars.add_child(bar)
		extra_bar_entries.append({
			"bar": bar,
			"config": config,
		})

func _update_bar(bar: ResourceBarScript, config: Resource) -> void:
	if bar == null or config == null or combatant == null:
		return

	var resource_id := str(config.get("resource_id"))
	var snapshot := combatant.get_resource_snapshot(resource_id)
	var current_value := int(snapshot.get("current", 0))
	var reference_value := int(snapshot.get("reference", int(config.get("reference_value"))))
	var bonus_value := int(snapshot.get("bonus", 0))

	bar.set_values(current_value, reference_value, bonus_value)

func _update_status_label() -> void:
	if status_label == null or combatant == null:
		return

	var entries := _status_label_entries()
	status_label.visible = not entries.is_empty()
	status_label.text = "[center]%s[/center]" % "   ".join(entries)

func _status_label_entries() -> Array[String]:
	var entries: Array[String] = []
	for status_id in combatant.statuses.keys():
		var state: Variant = combatant.statuses[status_id]
		if not state is Dictionary:
			continue

		var remaining_seconds := float(state.get("remaining_seconds", 0.0))
		if remaining_seconds <= 0.0:
			continue

		var display_name := str(status_id).capitalize()
		var status_data: Variant = state.get("data", null)
		if status_data != null:
			var raw_display_name: Variant = status_data.get("display_name")
			if raw_display_name is String and not raw_display_name.is_empty():
				display_name = raw_display_name

		entries.append(
			"[color=%s][b]%s[/b] %ss[/color]" % [
				_status_color(str(status_id)),
				_escape_bbcode(display_name),
				int(ceil(remaining_seconds)),
			]
		)

	return entries

func _status_color(status_id: String) -> String:
	match status_id:
		"vulnerable":
			return "ff8c6f"
		"weaken":
			return "d9e76c"
		_:
			return "f2f4f8"

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")

func _clear_extra_resource_bars() -> void:
	for entry in extra_bar_entries:
		var bar := entry.get("bar") as Node
		if bar != null and is_instance_valid(bar):
			bar.queue_free()
	extra_bar_entries.clear()
	_clear_spacers()

func _clear_spacers() -> void:
	for spacer in spacer_nodes:
		if spacer != null and is_instance_valid(spacer):
			spacer.queue_free()
	spacer_nodes.clear()
