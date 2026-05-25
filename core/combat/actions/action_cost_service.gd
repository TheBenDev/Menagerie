## Validates and spends player action start costs before an action is queued.
class_name ActionCostService
extends RefCounted

static func usability_error(actor: Combatant, action: CombatActionData) -> String:
	if actor == null:
		return "Missing actor."
	if action == null:
		return "Missing action."
	if actor.hp <= 0:
		return "Actor cannot act while defeated."
	if action.hp_cost > 0 and actor.hp <= action.hp_cost:
		return "Not enough HP."
	if action is PlayerActionData:
		var player_action := action as PlayerActionData
		for raw_resource_id in player_action.resource_costs.keys():
			var resource_id := StringName(str(raw_resource_id))
			var resource_cost := int(player_action.resource_costs[raw_resource_id])
			if resource_id == &"" or resource_cost <= 0:
				continue
			if not actor.has_method("get_class_resource_amount"):
				return "Requires %s." % _resource_display_name(resource_id, actor)
			if int(actor.call("get_class_resource_amount", resource_id)) < resource_cost:
				return "Requires %s %s." % [resource_cost, _resource_display_name(resource_id, actor)]
		var required_stance := StringName(player_action.required_stance.strip_edges())
		if required_stance != &"":
			if not actor.has_method("get_active_stance_id"):
				return "Requires %s stance." % required_stance
			if actor.call("get_active_stance_id") != required_stance:
				return "Requires %s stance." % String(required_stance).capitalize()
	return ""

static func can_use(actor: Combatant, action: CombatActionData) -> bool:
	return usability_error(actor, action).is_empty()

static func spend_start_costs(actor: Combatant, action: CombatActionData) -> String:
	var error := usability_error(actor, action)
	if not error.is_empty():
		return error
	if action.hp_cost > 0:
		actor.hp = max(actor.hp - action.hp_cost, 1)
		actor.hp_changed.emit(actor)
	if action is PlayerActionData:
		var player_action := action as PlayerActionData
		for raw_resource_id in player_action.resource_costs.keys():
			var resource_id := StringName(str(raw_resource_id))
			var resource_cost := int(player_action.resource_costs[raw_resource_id])
			if resource_id == &"" or resource_cost <= 0:
				continue
			if not actor.has_method("spend_class_resource"):
				return "Could not spend %s." % _resource_display_name(resource_id, actor)
			if not bool(actor.call("spend_class_resource", resource_id, resource_cost)):
				return "Could not spend %s." % _resource_display_name(resource_id, actor)
	return ""

static func _resource_display_name(resource_id: StringName, actor: Combatant) -> String:
	if actor != null and actor.has_method("class_resource_display_name"):
		var display := str(actor.call("class_resource_display_name", resource_id)).strip_edges()
		if not display.is_empty():
			return display
	return String(resource_id).replace("_", " ").capitalize()
