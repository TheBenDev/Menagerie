## Blocking dungeon overlay for selecting pending class reward options.
class_name ClassRewardChoiceOverlay
extends Control

signal class_reward_selected(context_id: String, reward_id: StringName)

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const ValueReaderScript := preload("res://core/utils/value_reader.gd")
const HOVER_INFO_META := &"hover_info_data"

@onready var title_label: Label = $DimOverlay/RewardPanel/PanelMargin/Layout/TitleLabel
@onready var description_label: Label = $DimOverlay/RewardPanel/PanelMargin/Layout/DescriptionLabel
@onready var options_container: VBoxContainer = $DimOverlay/RewardPanel/PanelMargin/Layout/OptionsContainer

var reward_snapshot: Dictionary = {}
var is_interactive: bool = true
var hover_tooltip_layer: Node = null

func setup(snapshot: Dictionary) -> void:
	reward_snapshot = snapshot.duplicate(true)
	_refresh()

func set_hover_tooltip_layer(new_hover_tooltip_layer: Node) -> void:
	hover_tooltip_layer = new_hover_tooltip_layer
	_bind_option_buttons()

func set_interactive(new_is_interactive: bool) -> void:
	is_interactive = new_is_interactive
	for child in options_container.get_children():
		var button := child as Button
		if button != null:
			button.disabled = not is_interactive

func _refresh() -> void:
	var source := str(reward_snapshot.get("source", "memory"))
	title_label.text = "Class Reward"
	description_label.text = "Choose one reward." if source == "memory" else "Choose one rare reward."
	_rebuild_option_buttons()

func _rebuild_option_buttons() -> void:
	for child in options_container.get_children():
		child.queue_free()

	var options: Array = reward_snapshot.get("options", [])
	for raw_option in options:
		if not (raw_option is Dictionary):
			continue
		var option: Dictionary = raw_option
		var button := Button.new()
		button.text = _option_button_text(option)
		button.tooltip_text = ""
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not is_interactive
		button.pressed.connect(_on_option_pressed.bind(StringName(str(option.get("reward_id", "")))))
		_set_button_hover_info(button, _option_hover_info(option))
		options_container.add_child(button)
	_bind_option_buttons()

func _option_button_text(option: Dictionary) -> String:
	var display_name := str(option.get("display_name", "")).strip_edges()
	var rarity := str(option.get("rarity", "")).strip_edges().capitalize()
	if rarity.is_empty():
		return display_name
	return "%s  [%s]" % [display_name, rarity]

func _option_hover_info(option: Dictionary) -> Resource:
	var info := HoverInfoDataScript.new()
	info.title = str(option.get("display_name", "")).strip_edges()
	info.subtitle = str(option.get("rarity", "")).strip_edges().capitalize()
	info.description = str(option.get("description", "")).strip_edges()
	info.keyword_ids.append_array(ValueReaderScript.string_name_array(option.get("hover_keywords", [])))
	info.panel_style = &"class_reward"
	return info

func _set_button_hover_info(button: Button, info: Resource) -> void:
	if button == null:
		return
	if info == null:
		if button.has_meta(HOVER_INFO_META):
			button.remove_meta(HOVER_INFO_META)
		return
	button.set_meta(HOVER_INFO_META, info)
	_bind_hover_source(button)

func _bind_option_buttons() -> void:
	if options_container == null:
		return
	for child in options_container.get_children():
		var button := child as Button
		if button != null and button.has_meta(HOVER_INFO_META):
			_bind_hover_source(button)

func _bind_hover_source(source: Control) -> void:
	if hover_tooltip_layer != null and source != null:
		hover_tooltip_layer.call("bind_source", source)

func _on_option_pressed(reward_id: StringName) -> void:
	if reward_id == &"":
		push_error("Class reward selection is missing reward_id.")
		return
	class_reward_selected.emit(str(reward_snapshot.get("context_id", "")), reward_id)
