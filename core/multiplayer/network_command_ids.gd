## Shared command and session mode identifiers for the multiplayer authority boundary.
class_name NetworkCommandIds
extends RefCounted

const MODE_OFFLINE := "offline"
const MODE_HOST := "host"
const MODE_CLIENT := "client"

const START_RUN := "run.request_start"
const ROUTE := "route.request_change"
const PAWN_TRAVEL := "dungeon.request_pawn_travel"
const ENCOUNTER_CHOICE := "dungeon.request_encounter_choice"
const COMBAT_ACTION := "combat.request_action"
const CLASS_REWARD_CHOICE := "class.request_reward_choice"

const ROUTE_MAIN_MENU := "main_menu"
const ROUTE_WAITING_ROOM := "waiting_room"
const ROUTE_DUNGEON := "dungeon"
const ROUTE_COMBAT := "combat/BattleScene"
const ROUTE_RUN_SUMMARY := "run_summary"
