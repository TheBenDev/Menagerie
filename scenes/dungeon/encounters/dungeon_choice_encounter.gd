## Generic dungeon encounter presentation scene that renders resource-authored choices and emits the selected result.
class_name DungeonChoiceEncounter
extends Control

signal encounter_finished(result: Dictionary)


@onready var title_label: Label = $EncounterPanel/PanelMargin/Layout/TitleLabel
@onready var description_label: Label = $EncounterPanel/PanelMargin/Layout/DescriptionLabel
@onready var choices_container: VBoxContainer = $EncounterPanel/PanelMargin/Layout/ChoicesContainer

var encounter_data: Resource = null
var encounter_context: Dictionary = {}

func setup(new_encounter_data: Resource, context: Dictionary) -> void:
	encounter_data = new_encounter_data
	encounter_context = context.duplicate(true)
	_refresh()

func _refresh() -> void:
	if encounter_data == null:
		title_label.text = "Encounter"
		description_label.text = ""
		_create_continue_button()
		return

	title_label.text = str(encounter_data.get("display_name"))
	description_label.text = str(encounter_data.get("description"))
	_rebuild_choice_buttons()

func _rebuild_choice_buttons() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	var choices: Array = encounter_data.get("choices")
	if encounter_data == null or choices.is_empty():
		_create_continue_button()
		return

	for choice_index in choices.size():
		var choice: Variant = choices[choice_index]
		if not (choice is Dictionary):
			continue

		var choice_data: Dictionary = choice
		var button := Button.new()
		button.text = str(choice_data.get("label", "Continue"))
		button.tooltip_text = _choice_tooltip(choice_data)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_choice_pressed.bind(choice_index))
		choices_container.add_child(button)

func _create_continue_button() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	var button := Button.new()
	button.text = "Continue"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_choice_pressed.bind(-1))
	choices_container.add_child(button)

func _choice_tooltip(choice_data: Dictionary) -> String:
	var parts: Array[String] = []
	var description := str(choice_data.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	var effect_summary := _effect_summary(choice_data)
	if not effect_summary.is_empty():
		parts.append(effect_summary)

	return "\n".join(parts)

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
