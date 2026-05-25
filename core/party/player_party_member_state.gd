## Stores player-party metadata for one character while referencing reusable combatant runtime state.
class_name PlayerPartyMemberState
extends RefCounted

const PartyControlModeScript := preload("res://core/party/party_control_mode.gd")

var party_member_id: String = ""
var character_id: String = ""
var combatant_state: CombatantState = null
var control_mode: int = PartyControlModeScript.LOCAL_PLAYER
var owner_peer_id: int = 1
var platform_user_id: String = ""
var map_pawn_id: String = ""
var is_unlocked: bool = true
var is_active: bool = true
var class_run_state: Variant = null
var class_profile: Resource = null

func _init(
	new_party_member_id: String = "",
	new_character_id: String = "",
	new_combatant_state: CombatantState = null,
	new_control_mode: int = PartyControlModeScript.LOCAL_PLAYER,
	new_owner_peer_id: int = 1,
	new_platform_user_id: String = ""
) -> void:
	party_member_id = new_party_member_id
	character_id = new_character_id
	combatant_state = new_combatant_state
	control_mode = new_control_mode
	owner_peer_id = max(new_owner_peer_id, 1)
	platform_user_id = new_platform_user_id.strip_edges()

func control_mode_id() -> String:
	return PartyControlModeScript.id_for_mode(control_mode)

func is_locally_controlled() -> bool:
	return is_unlocked and is_active and PartyControlModeScript.can_accept_local_input(control_mode)

func should_follow_leader() -> bool:
	return is_unlocked and is_active and PartyControlModeScript.should_follow_leader(control_mode)

func can_act_on_dungeon_map() -> bool:
	return is_unlocked and is_active and PartyControlModeScript.can_act_on_dungeon_map(control_mode)

func is_inactive() -> bool:
	return not is_active or not PartyControlModeScript.is_active_mode(control_mode)
