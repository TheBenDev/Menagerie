## Owns the player party roster, active member IDs, leader selection, and current member selection.
class_name PlayerPartyState
extends RefCounted

const CombatantStateScript := preload("res://core/combat/combatant_state.gd")
const PartyControlModeScript := preload("res://core/party/party_control_mode.gd")
const PlayerPartyMemberStateScript := preload("res://core/party/player_party_member_state.gd")

var members: Dictionary = {}
var active_member_ids: Array[String] = []
var leader_member_id: String = ""
var selected_member_id: String = ""

## Resets this party to one active local-player member.
func configure_single_member(character_id: String, profile_path: String, profile: Resource) -> void:
	members.clear()
	active_member_ids.clear()
	leader_member_id = ""
	selected_member_id = ""

	var normalized_id := _normalized_id(character_id)
	var combatant_state := CombatantStateScript.new(
		"combatant.%s" % normalized_id,
		profile_path,
		profile
	)
	var member := PlayerPartyMemberStateScript.new(
		"party_member.%s" % normalized_id,
		character_id,
		combatant_state,
		PartyControlModeScript.LOCAL_PLAYER
	)
	add_member(member, true)
	leader_member_id = member.party_member_id
	selected_member_id = member.party_member_id

## Adds or replaces one party member and optionally marks it active.
func add_member(member: Variant, make_active: bool = true) -> void:
	if member == null or member.party_member_id.is_empty():
		return

	members[member.party_member_id] = member
	if make_active and not active_member_ids.has(member.party_member_id):
		active_member_ids.append(member.party_member_id)
	if leader_member_id.is_empty():
		leader_member_id = member.party_member_id
	if selected_member_id.is_empty():
		selected_member_id = member.party_member_id

func get_member(party_member_id: String) -> Variant:
	return members.get(party_member_id, null)

func get_leader() -> Variant:
	return get_member(leader_member_id)

func get_selected_member() -> Variant:
	return get_member(selected_member_id)

func get_selected_combatant_state() -> Variant:
	var member: Variant = get_selected_member()
	if member != null:
		return member.combatant_state

	member = get_leader()
	if member != null:
		return member.combatant_state

	return null

func get_active_members() -> Array:
	var active_members: Array = []
	for member_id in active_member_ids:
		var member: Variant = get_member(member_id)
		if member != null and member.is_active:
			active_members.append(member)

	return active_members

func get_member_for_combatant_id(combatant_id: String) -> Variant:
	for member in members.values():
		var party_member = member
		if party_member == null or party_member.combatant_state == null:
			continue
		if party_member.combatant_state.combatant_id == combatant_id:
			return party_member

	return null

func has_active_member(party_member_id: String) -> bool:
	return active_member_ids.has(party_member_id)

static func _normalized_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "_")
	if normalized.is_empty():
		return "member"

	return normalized
