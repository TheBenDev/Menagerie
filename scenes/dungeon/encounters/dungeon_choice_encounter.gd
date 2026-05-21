## Generic dungeon encounter presentation scene that renders resource-authored choices and emits the selected result.
class_name DungeonChoiceEncounter
extends Control

signal encounter_finished(result: Dictionary)

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const HOVER_INFO_META := &"hover_info_data"

@onready var title_label: Label = $EncounterPanel/PanelMargin/Layout/TitleLabel
@onready var description_label: Label = $EncounterPanel/PanelMargin/Layout/DescriptionLabel
@onready var choices_container: VBoxContainer = $EncounterPanel/PanelMargin/Layout/ChoicesContainer

var encounter_data: Resource = null
var encounter_context: Dictionary = {}
var is_interactive: bool = true
var hover_tooltip_layer: Node = null

func setup(new_encounter_data: Resource, context: Dictionary) -> void:
	encounter_data = new_encounter_data
	encounter_context = context.duplicate(true)
	_refresh()

func set_hover_tooltip_layer(new_hover_tooltip_layer: Node) -> void:
	hover_tooltip_layer = new_hover_tooltip_layer
	_bind_choice_buttons()

func _refresh() -> void:
	if encounter_data == null:
		title_label.text = "Encounter"
		description_label.text = ""
		_create_continue_button()
		return

	title_label.text = str(_encounter_value("display_name", "Encounter"))
	description_label.text = str(_encounter_value("description", ""))
	_rebuild_choice_buttons()

func _rebuild_choice_buttons() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	if encounter_data == null:
		_create_continue_button()
		return

	var raw_choices: Variant = _encounter_value("choices", [])
	if not (raw_choices is Array):
		_create_continue_button()
		return
	var choices: Array = raw_choices
	if choices.is_empty():
		_create_continue_button()
		return

	for choice_index in choices.size():
		var choice: Variant = choices[choice_index]
		if not (choice is Dictionary):
			continue

		var choice_data: Dictionary = choice
		var button := Button.new()
		button.text = str(choice_data.get("label", "Continue"))
		button.tooltip_text = ""
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not is_interactive
		button.pressed.connect(_on_choice_pressed.bind(choice_index))
		_set_choice_hover_info(button, _choice_hover_info(choice_data))
		choices_container.add_child(button)

func _create_continue_button() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	var button := Button.new()
	button.text = "Continue"
	button.tooltip_text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not is_interactive
	button.pressed.connect(_on_choice_pressed.bind(-1))
	choices_container.add_child(button)

func set_interactive(new_is_interactive: bool) -> void:
	is_interactive = new_is_interactive
	for child in choices_container.get_children():
		var button := child as Button
		if button != null:
			button.disabled = not is_interactive

func _choice_hover_info(choice_data: Dictionary) -> Resource:
	var parts: Array[String] = []
	var description := str(choice_data.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	var effect_summary := _effect_summary(choice_data)
	if not effect_summary.is_empty():
		parts.append(effect_summary)
	if parts.is_empty():
		return null

	var info := HoverInfoDataScript.new()
	info.title = str(choice_data.get("label", "Choice")).strip_edges()
	info.description = "\n".join(parts)
	info.panel_style = &"encounter_choice"
	return info

func _set_choice_hover_info(button: Button, info: Resource) -> void:
	if button == null:
		return
	if info == null:
		if button.has_meta(HOVER_INFO_META):
			button.remove_meta(HOVER_INFO_META)
		return

	button.set_meta(HOVER_INFO_META, info)
	_bind_hover_source(button)

func _bind_choice_buttons() -> void:
	if choices_container == null:
		return

	for child in choices_container.get_children():
		var button := child as Button
		if button != null and button.has_meta(HOVER_INFO_META):
			_bind_hover_source(button)

func _bind_hover_source(source: Control) -> void:
	if hover_tooltip_layer != null and source != null:
		hover_tooltip_layer.call("bind_source", source)

func _effect_summary(choice_data: Dictionary) -> String:
	var summaries: Array[String] = []
	var effects: Array = choice_data.get("effects", [])
	for effect in effects:
		if not (effect is Dictionary):
			continue

		var effect_data: Dictionary = effect
		var effect_id := str(effect_data.get("id", ""))
		var amount := int(effect_data.get("amount", 0))
		match effect_id:
			"damage":
				summaries.append("Take %s damage" % max(amount, 0))
			"stat":
				var duration_text := "permanently" if bool(effect_data.get("permanent", false)) else "for %ss" % int(round(float(effect_data.get("duration", 0.0))))
				summaries.append("%+d %s %s" % [amount, StatId.from_value(effect_data.get("stat", StatId.STR)), duration_text])

	return ", ".join(summaries)

func _on_choice_pressed(choice_index: int) -> void:
	encounter_finished.emit({
		"mode": "complete",
		"choice_index": choice_index,
		"context": encounter_context,
	})

func _encounter_value(field_name: String, default_value: Variant) -> Variant:
	if encounter_data == null:
		return default_value

	var value: Variant = encounter_data.get(field_name)
	return default_value if value == null else value
