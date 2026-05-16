## Defines party member control modes and small behavior helpers for dungeon-map command routing.
class_name PartyControlMode
extends RefCounted

enum Mode {
	LOCAL_PLAYER,
	AUTO_PILOT,
	REMOTE_PLAYER,
	INACTIVE,
}

const LOCAL_PLAYER := Mode.LOCAL_PLAYER
const AUTO_PILOT := Mode.AUTO_PILOT
const REMOTE_PLAYER := Mode.REMOTE_PLAYER
const INACTIVE := Mode.INACTIVE

const LOCAL_PLAYER_ID := "LocalPlayer"
const AUTO_PILOT_ID := "AutoPilot"
const REMOTE_PLAYER_ID := "RemotePlayer"
const INACTIVE_ID := "Inactive"

static func id_for_mode(mode: int) -> String:
	match mode:
		LOCAL_PLAYER:
			return LOCAL_PLAYER_ID
		AUTO_PILOT:
			return AUTO_PILOT_ID
		REMOTE_PLAYER:
			return REMOTE_PLAYER_ID
		INACTIVE:
			return INACTIVE_ID
		_:
			return INACTIVE_ID

static func mode_for_id(mode_id: String) -> int:
	var normalized := mode_id.strip_edges().replace("_", "").replace(" ", "").to_lower()
	match normalized:
		"localplayer", "local":
			return LOCAL_PLAYER
		"autopilot", "auto":
			return AUTO_PILOT
		"remoteplayer", "remote":
			return REMOTE_PLAYER
		"inactive":
			return INACTIVE
		_:
			return INACTIVE

static func can_accept_local_input(mode: int) -> bool:
	return mode == LOCAL_PLAYER

static func should_follow_leader(mode: int) -> bool:
	return mode == AUTO_PILOT

static func can_act_on_dungeon_map(mode: int) -> bool:
	return mode == LOCAL_PLAYER or mode == AUTO_PILOT

static func is_active_mode(mode: int) -> bool:
	return mode != INACTIVE
