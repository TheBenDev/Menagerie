## Resource definition for a combat action, including timing, costs, effect data, audio, and targeting.
class_name CombatActionData
extends Resource

const CombatEffectLibraryScript := preload("res://core/combat/actions/combat_effect_library.gd")
const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")
const HoverInfoTextSegmentScript := preload("res://core/hover_info/hover_info_text_segment.gd")
const HoverInfoKeywordResolverScript := preload("res://core/hover_info/hover_info_keyword_resolver.gd")
const StrengthStatIcon: Texture2D = preload("res://assets/ui/global/icons/strength_stat_icon.tres")
const DexterityStatIcon: Texture2D = preload("res://assets/ui/global/icons/dexterity_stat_icon.tres")
const IntelligenceStatIcon: Texture2D = preload("res://assets/ui/global/icons/intelligence_stat_icon.tres")
const VitalityStatIcon: Texture2D = preload("res://assets/ui/global/icons/vitality_stat_icon.tres")

const TARGET_SINGLE_ENEMY := "SingleEnemy"
const TARGET_SINGLE_ALLY := "SingleAlly"
const TARGET_RANDOM_ENEMY := "RandomEnemy"
const TARGET_SELF := "Self"
const TARGET_ALL_ALLIES := "AllAllies"
const TARGET_ALL_ENEMIES := "AllEnemies"
const STATUS_TEXT_FALLBACK_COLOR := Color(0.88, 0.76, 0.42, 1.0)
const BLOCK_KEYWORD_ID := &"resource.block"
const BLOCK_TEXT_FALLBACK_COLOR := Color(0.32, 0.66, 1.0, 1.0)
const RESOURCE_TEXT_FALLBACK_COLOR := Color(0.95, 0.42, 0.12, 1.0)
const INLINE_STAT_ICON_SIZE := Vector2(15.0, 15.0)

@export var id: String = ""
@export var display_name: String = "Action"
@export_multiline var description: String = ""

@export var effect_data: Array[Dictionary] = []

@export var start_sfx_id: StringName = &""
@export var resolve_sfx_id: StringName = &""

@export var time_cost: float = 5.0
@export var hp_cost: int = 0
;# Reserved for future mana users; current resolution intentionally does not spend mana.
@export var mana_cost: int = 0

@export_enum("SingleEnemy", "SingleAlly", "RandomEnemy", "Self", "AllAllies", "AllEnemies") var target_rule: String = TARGET_SINGLE_ENEMY

@export_group("Hover Info")
@export var hover_icon: Texture2D = null
@export var hover_title: String = ""
@export_multiline var hover_description: String = ""
@export var hover_keywords: Array[StringName] = []
@export var hover_fields: Array[Resource] = []
@export var hover_footer: String = ""

func get_hover_info(actor: Combatant = null, show_formula: bool = false) -> Resource:
	var info := HoverInfoDataScript.new()
	info.icon = hover_icon
	info.title = hover_title.strip_edges()
	if info.title.is_empty():
		info.title = display_name
	info.header_right_text = "%ss" % CombatTime.format_seconds(time_cost)
	_populate_description(info, actor, show_formula)
	info.footer = hover_footer.strip_edges()
	_populate_keyword_ids(info, actor)
	info.panel_style = &"action"

	if hp_cost > 0:
		info.add_field("HP Cost", str(hp_cost))
	if mana_cost > 0:
		info.add_field("Mana Cost", str(mana_cost))
	var resource_costs_value: Variant = get("resource_costs")
	if resource_costs_value is Dictionary:
		var resource_costs: Dictionary = resource_costs_value
		for raw_resource_id in resource_costs.keys():
			var resource_id := StringName(str(raw_resource_id))
			var amount := int(resource_costs[raw_resource_id])
			if resource_id != &"" and amount > 0:
				info.add_field("%s Cost" % _resource_display_name(resource_id, actor), str(amount))
	info.add_field("Target", _target_label())
	info.fields.append_array(hover_fields)
	return info

func _populate_description(info: Resource, actor: Combatant, show_formula: bool) -> void:
	var base_description := _description_for_hover()
	var effect_segments := _effect_description_segments(actor, show_formula)
	var effect_text := _effect_description_text(actor, show_formula)

	info.description = base_description
	if not effect_text.is_empty():
		if info.description.is_empty():
			info.description = effect_text
		else:
			info.description += "\n" + effect_text

	if not base_description.is_empty():
		info.add_description_text(base_description)
		if not effect_segments.is_empty():
			info.add_description_text("\n")
	info.description_segments.append_array(effect_segments)

func _description_for_hover() -> String:
	var authored_description := hover_description.strip_edges()
	if not authored_description.is_empty():
		return authored_description

	var base_description := description.strip_edges()
	if not base_description.is_empty():
		return base_description

	var tooltip_value: Variant = get("tooltip_text")
	if tooltip_value != null:
		return str(tooltip_value).strip_edges()

	return ""

func _populate_keyword_ids(info: Resource, actor: Combatant) -> void:
	for keyword_id in hover_keywords:
		_append_unique_keyword_id(info.keyword_ids, keyword_id)

	for effect in effect_data:
		if not (effect is Dictionary):
			continue
		match CombatEffectLibraryScript.effect_id_for_data(effect):
			CombatEffectLibraryScript.EFFECT_APPLY_STATUS:
				var status_data := CombatEffectLibraryScript.status_data_for_effect(effect)
				_append_unique_keyword_id(info.keyword_ids, _keyword_id_for_status_effect(effect, status_data))
			CombatEffectLibraryScript.EFFECT_BLOCK:
				_append_unique_keyword_id(info.keyword_ids, BLOCK_KEYWORD_ID)
			CombatEffectLibraryScript.EFFECT_RESOURCE_GAIN:
				_append_unique_keyword_id(
					info.keyword_ids,
					_resource_keyword_id(CombatEffectLibraryScript.resource_id_for_effect(effect), actor)
				)

func _effect_description_segments(actor: Combatant, show_formula: bool) -> Array[Resource]:
	var segments: Array[Resource] = []
	var damage_breakdowns := _damage_breakdowns(actor)
	var applied_statuses := _applied_statuses()
	var block_gain_amount := _block_gain_amount()
	var resource_gain_entries := _resource_gain_entries(actor)
	if damage_breakdowns.is_empty() and applied_statuses.is_empty() and block_gain_amount <= 0 and resource_gain_entries.is_empty():
		return segments

	if not damage_breakdowns.is_empty():
		segments.append(HoverInfoTextSegmentScript.from_text("Deals "))
		for index in damage_breakdowns.size():
			if index > 0:
				segments.append(HoverInfoTextSegmentScript.from_text(" and "))
			if show_formula:
				_append_damage_formula_segments(segments, damage_breakdowns[index])
			else:
				segments.append(HoverInfoTextSegmentScript.from_text(str(int(damage_breakdowns[index].get("total_damage", 0)))))
		segments.append(HoverInfoTextSegmentScript.from_text(" damage"))

	if not applied_statuses.is_empty():
		segments.append(HoverInfoTextSegmentScript.from_text(" and applies " if not damage_breakdowns.is_empty() else "Applies "))
		_append_status_segments(segments, applied_statuses)

	if not damage_breakdowns.is_empty() or not applied_statuses.is_empty():
		segments.append(HoverInfoTextSegmentScript.from_text("."))

	if block_gain_amount > 0:
		_append_spaced_effect_sentence(segments)
		_append_resource_gain_segments(segments, block_gain_amount, "Block", BLOCK_KEYWORD_ID, BLOCK_TEXT_FALLBACK_COLOR)

	for resource_gain in resource_gain_entries:
		_append_spaced_effect_sentence(segments)
		var fallback_color: Color = resource_gain.get("fallback_color", RESOURCE_TEXT_FALLBACK_COLOR)
		_append_resource_gain_segments(
			segments,
			int(resource_gain.get("amount", 0)),
			str(resource_gain.get("display_name", "")),
			StringName(str(resource_gain.get("keyword_id", &""))),
			fallback_color
		)

	return segments

func _effect_description_text(actor: Combatant, show_formula: bool) -> String:
	var damage_breakdowns := _damage_breakdowns(actor)
	var applied_statuses := _applied_statuses()
	var block_gain_amount := _block_gain_amount()
	var resource_gain_entries := _resource_gain_entries(actor)
	if damage_breakdowns.is_empty() and applied_statuses.is_empty() and block_gain_amount <= 0 and resource_gain_entries.is_empty():
		return ""

	var text := ""
	if not damage_breakdowns.is_empty():
		var damage_parts := PackedStringArray()
		for breakdown in damage_breakdowns:
			damage_parts.append(_damage_formula_text(breakdown) if show_formula else str(int(breakdown.get("total_damage", 0))))
		text = "Deals %s damage" % " and ".join(damage_parts)

	if not applied_statuses.is_empty():
		var status_names := PackedStringArray()
		for status in applied_statuses:
			status_names.append(str(status.get("display_name", "")))
		var status_text := _joined_names(status_names)
		if text.is_empty():
			text = "Applies %s" % status_text
		else:
			text += " and applies %s" % status_text

	var sentences: PackedStringArray = []
	if not text.is_empty():
		sentences.append(text + ".")
	if block_gain_amount > 0:
		sentences.append("Gain %s Block." % block_gain_amount)
	for resource_gain in resource_gain_entries:
		sentences.append("Gain %s %s." % [
			int(resource_gain.get("amount", 0)),
			str(resource_gain.get("display_name", "")),
		])

	return " ".join(sentences)

func _damage_breakdowns(actor: Combatant) -> Array[Dictionary]:
	var breakdowns: Array[Dictionary] = []
	for effect in effect_data:
		if not (effect is Dictionary):
			continue
		if CombatEffectLibraryScript.effect_id_for_data(effect) == CombatEffectLibraryScript.EFFECT_DAMAGE:
			breakdowns.append(CombatEffectLibraryScript.damage_breakdown(effect, actor))

	return breakdowns

func _applied_statuses() -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	var seen_status_ids: Dictionary = {}
	for effect in effect_data:
		if not (effect is Dictionary):
			continue
		if CombatEffectLibraryScript.effect_id_for_data(effect) != CombatEffectLibraryScript.EFFECT_APPLY_STATUS:
			continue

		var status_data := CombatEffectLibraryScript.status_data_for_effect(effect)
		var status_id := str(_keyword_id_for_status_effect(effect, status_data))
		if status_id.is_empty() or seen_status_ids.has(status_id):
			continue

		seen_status_ids[status_id] = true
		statuses.append({
			"id": status_id,
			"display_name": _status_display_name(status_id, status_data),
			"color": _status_keyword_color(status_data),
		})

	return statuses

func _block_gain_amount() -> int:
	var total_amount := 0
	for effect in effect_data:
		if not (effect is Dictionary):
			continue
		if CombatEffectLibraryScript.effect_id_for_data(effect) == CombatEffectLibraryScript.EFFECT_BLOCK:
			total_amount += max(CombatEffectLibraryScript.block_amount(effect), 0)

	return total_amount

func _resource_gain_entries(actor: Combatant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for effect in effect_data:
		if not (effect is Dictionary):
			continue
		if CombatEffectLibraryScript.effect_id_for_data(effect) != CombatEffectLibraryScript.EFFECT_RESOURCE_GAIN:
			continue
		var resource_id := CombatEffectLibraryScript.resource_id_for_effect(effect)
		if resource_id == &"":
			push_error("Action %s has resource.gain hover effect without resource_id." % id)
			continue
		var amount: int = max(CombatEffectLibraryScript.effect_amount(effect, 0), 0)
		if amount <= 0:
			continue

		var existing_index := -1
		for index in entries.size():
			if StringName(entries[index].get("id", &"")) == resource_id:
				existing_index = index
				break
		if existing_index >= 0:
			entries[existing_index]["amount"] = int(entries[existing_index].get("amount", 0)) + amount
		else:
			entries.append({
				"id": resource_id,
				"amount": amount,
				"display_name": _resource_display_name(resource_id, actor),
				"keyword_id": _resource_keyword_id(resource_id, actor),
				"fallback_color": _resource_keyword_color(resource_id, actor),
			})

	return entries

func _append_damage_formula_segments(segments: Array[Resource], breakdown: Dictionary) -> void:
	segments.append(HoverInfoTextSegmentScript.from_text(str(int(breakdown.get("base_damage", 0)))))
	if not is_equal_approx(float(breakdown.get("scaling_multiplier", 0.0)), 0.0):
		segments.append(HoverInfoTextSegmentScript.from_text(" + ("))
		segments.append(HoverInfoTextSegmentScript.from_text("%sx" % _format_multiplier(float(breakdown.get("scaling_multiplier", 0.0)))))
		var stat_icon := _stat_icon(str(breakdown.get("scaling_stat", StatId.STR)))
		if stat_icon != null:
			segments.append(HoverInfoTextSegmentScript.from_text(" "))
			segments.append(HoverInfoTextSegmentScript.from_icon(stat_icon, INLINE_STAT_ICON_SIZE))
		else:
			segments.append(HoverInfoTextSegmentScript.from_text(" %s" % str(breakdown.get("scaling_stat", StatId.STR))))
		segments.append(HoverInfoTextSegmentScript.from_text(")"))

func _append_status_segments(segments: Array[Resource], statuses: Array[Dictionary]) -> void:
	for index in statuses.size():
		if index > 0:
			segments.append(HoverInfoTextSegmentScript.from_text(" and " if index == statuses.size() - 1 else ", "))

		var status := statuses[index]
		var status_color: Color = status.get("color", STATUS_TEXT_FALLBACK_COLOR)
		segments.append(HoverInfoTextSegmentScript.from_text(
			str(status.get("display_name", "")),
			status_color,
			true
		))

func _append_spaced_effect_sentence(segments: Array[Resource]) -> void:
	if not segments.is_empty():
		segments.append(HoverInfoTextSegmentScript.from_text(" "))

func _append_resource_gain_segments(
	segments: Array[Resource],
	amount: int,
	keyword_display_name: String,
	keyword_id: StringName,
	fallback_color: Color
) -> void:
	segments.append(HoverInfoTextSegmentScript.from_text("Gain %s " % amount))
	segments.append(HoverInfoTextSegmentScript.from_text(
		keyword_display_name,
		HoverInfoKeywordResolverScript.keyword_color_for_id(keyword_id, fallback_color),
		true
	))
	segments.append(HoverInfoTextSegmentScript.from_text("."))

func _damage_formula_text(breakdown: Dictionary) -> String:
	var base_damage := int(breakdown.get("base_damage", 0))
	if is_equal_approx(float(breakdown.get("scaling_multiplier", 0.0)), 0.0):
		return str(base_damage)

	return "%s + (%sx %s)" % [
		base_damage,
		_format_multiplier(float(breakdown.get("scaling_multiplier", 0.0))),
		str(breakdown.get("scaling_stat", StatId.STR)),
	]

func _keyword_id_for_status_effect(effect: Dictionary, status_data: Resource) -> StringName:
	if status_data != null:
		var status_data_id := str(status_data.get("id")).strip_edges()
		if not status_data_id.is_empty():
			return StringName(status_data_id)

	var status_id_value: Variant = effect.get("status_id", &"")
	return StringName(str(status_id_value).replace("status.", "").strip_edges())

func _status_display_name(status_id: String, status_data: Resource) -> String:
	if status_data != null:
		var status_display_name := str(status_data.get("display_name")).strip_edges()
		if not status_display_name.is_empty():
			return status_display_name

	return status_id.capitalize()

func _status_keyword_color(status_data: Resource) -> Color:
	if status_data != null:
		var keyword_color_value: Variant = status_data.get("keyword_color")
		if keyword_color_value is Color:
			return keyword_color_value

	return STATUS_TEXT_FALLBACK_COLOR

func _resource_display_name(resource_id: StringName, actor: Combatant) -> String:
	if resource_id == &"":
		return ""
	if actor != null and actor.has_method("class_resource_display_name"):
		var display := str(actor.call("class_resource_display_name", resource_id)).strip_edges()
		if not display.is_empty():
			return display
	return String(resource_id).replace("_", " ").capitalize()

func _resource_keyword_id(resource_id: StringName, actor: Combatant) -> StringName:
	if resource_id == &"":
		return &""
	if actor != null and actor.has_method("class_resource_keyword_id"):
		return actor.call("class_resource_keyword_id", resource_id)
	return StringName("resource.%s" % String(resource_id))

func _resource_keyword_color(resource_id: StringName, actor: Combatant) -> Color:
	if resource_id != &"" and actor != null and actor.has_method("class_resource_keyword_color"):
		var color: Variant = actor.call("class_resource_keyword_color", resource_id, RESOURCE_TEXT_FALLBACK_COLOR)
		if color is Color:
			return color
	return RESOURCE_TEXT_FALLBACK_COLOR

func _append_unique_keyword_id(keyword_ids: Array[StringName], keyword_id: StringName) -> void:
	if keyword_id == &"" or keyword_ids.has(keyword_id):
		return

	keyword_ids.append(keyword_id)

func _stat_icon(stat_id: String) -> Texture2D:
	match StatId.from_value(stat_id):
		StatId.STR:
			return StrengthStatIcon
		StatId.DEX:
			return DexterityStatIcon
		StatId.INT:
			return IntelligenceStatIcon
		StatId.VIT:
			return VitalityStatIcon
		_:
			return null

func _format_multiplier(multiplier: float) -> String:
	if is_equal_approx(multiplier, roundf(multiplier)):
		return str(int(roundf(multiplier)))

	var text := "%.2f" % multiplier
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text

func _joined_names(names: PackedStringArray) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]

	var leading_names := PackedStringArray()
	for index in range(names.size() - 1):
		leading_names.append(names[index])
	return "%s, and %s" % [", ".join(leading_names), names[names.size() - 1]]

func _target_label() -> String:
	match target_rule:
		TARGET_SINGLE_ENEMY:
			return "Single enemy"
		TARGET_SINGLE_ALLY:
			return "Single ally"
		TARGET_RANDOM_ENEMY:
			return "Random enemy"
		TARGET_SELF:
			return "Self"
		TARGET_ALL_ALLIES:
			return "All allies"
		TARGET_ALL_ENEMIES:
			return "All enemies"
		_:
			return target_rule
