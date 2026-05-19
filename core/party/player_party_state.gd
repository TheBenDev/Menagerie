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

	var normalized_id: String = _normalized_id(character_id)
	var combatant_state: CombatantState = CombatantStateScript.new(
		"combatant.%s" % normalized_id,
		profile_path,
		profile
	) as CombatantState
	var member: PlayerPartyMemberState = PlayerPartyMemberStateScript.new(
		"party_member.%s" % normalized_id,
		character_id,
		combatant_state,
		PartyControlModeScript.LOCAL_PLAYER,
		1,
		""
	) as PlayerPartyMemberState
	add_member(member, true)
	leader_member_id = member.party_member_id
	selected_member_id = member.party_member_id

## Resets this party from authoritative network member configs.
func configure_members(member_configs: Array[Dictionary], local_peer_id: int) -> void:
	members.clear()
	active_member_ids.clear()
	leader_member_id = ""
	selected_member_id = ""
	if member_configs.is_empty():
		push_error("PlayerPartyState cannot configure an empty multiplayer party.")
		return

	for config in member_configs:
		var member: Variant = _member_from_config(config, local_peer_id)
		if member == null:
			continue
		add_member(member, bool(config.get("is_active", true)))
		if selected_member_id.is_empty() and int(member.owner_peer_id) == local_peer_id:
			selected_member_id = member.party_member_id

	if leader_member_id.is_empty() and not active_member_ids.is_empty():
		leader_member_id = active_member_ids[0]
	if selected_member_id.is_empty():
		selected_member_id = leader_member_id

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
	for member_id: String in active_member_ids:
		var member: Variant = get_member(member_id)
		if member != null and not member.is_inactive():
			active_members.append(member)

	return active_members

func get_member_for_combatant_id(combatant_id: String) -> Variant:
	for member in members.values():
		var party_member: Variant = member
		if party_member == null or party_member.combatant_state == null:
			continue
		if party_member.combatant_state.combatant_id == combatant_id:
			return party_member

	return null

func has_active_member(party_member_id: String) -> bool:
	if not active_member_ids.has(party_member_id):
		return false
	var member: Variant = get_member(party_member_id)
	if member == null:
		return false
	return not member.is_inactive()

static func _normalized_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "_")
	if normalized.is_empty():
		return "member"

	return normalized

func _member_from_config(config: Dictionary, local_peer_id: int) -> Variant:
	var character_id: String = str(config.get("character_id", "")).strip_edges()
	var profile_path: String = str(config.get("profile_path", "")).strip_edges()
	var party_member_id: String = str(config.get("party_member_id", "")).strip_edges()
	var combatant_id: String = str(config.get("combatant_id", "")).strip_edges()
	var owner_peer_id: int = int(config.get("owner_peer_id", 1))
	var platform_user_id: String = str(config.get("platform_user_id", "")).strip_edges()
	if character_id.is_empty() or profile_path.is_empty() or party_member_id.is_empty() or combatant_id.is_empty():
		push_error("Invalid multiplayer party member config: %s." % config)
		return null

	var profile := load(profile_path) as Resource
	if profile == null:
		push_error("Could not load multiplayer party profile %s for %s." % [profile_path, party_member_id])
		return null

	var combatant_state: CombatantState = CombatantStateScript.new(combatant_id, profile_path, profile) as CombatantState
	var control_mode: int = PartyControlModeScript.LOCAL_PLAYER if owner_peer_id == local_peer_id else PartyControlModeScript.REMOTE_PLAYER
	if bool(config.get("is_active", true)) == false:
		control_mode = PartyControlModeScript.INACTIVE
	else:
		control_mode = PartyControlModeScript.LOCAL_PLAYER if owner_peer_id == local_peer_id else PartyControlModeScript.REMOTE_PLAYER
	return PlayerPartyMemberStateScript.new(
		party_member_id,
		character_id,
		combatant_state,
		control_mode,
		owner_peer_id,
		platform_user_id
	) as PlayerPartyMemberState
