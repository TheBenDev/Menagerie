## Resource profile for combatant identity, stats, class kit, moveset registry, rewards, audio cues, and UI resource bars.
class_name CombatantProfile
extends Resource

const HoverInfoDataScript := preload("res://core/hover_info/hover_info_data.gd")

@export var display_name: String = "Combatant"
@export var placeholder_color: Color = Color(0.22, 0.24, 0.28)
@export var timeline_initial: String = "?"
@export var timeline_color: Color = Color.WHITE
@export var battle_visual_scene: PackedScene = null
@export var strength: int = 0
@export var dexterity: int = 0
@export var intelligence: int = 0
@export var vitality: int = 0
@export var stat_weights: Dictionary = {}
@export var class_profile: Resource = null
@export var moveset: CombatMovesetData = null
@export var enemy_ai_profile: EnemyAIProfile = null
@export var reward_profile: Resource = null
@export var hit_sfx_id: StringName = &""
@export var block_sfx_id: StringName = &""
@export var death_sfx_id: StringName = &""
@export var health_bar: Resource = null
@export var resource_bars: Array[Resource] = []

@export_group("Hover Info")
@export var hover_icon: Texture2D = null
@export var hover_title: String = ""
@export_multiline var hover_description: String = ""
@export var hover_keywords: Array[StringName] = []
@export var hover_fields: Array[Resource] = []
@export var hover_footer: String = ""

func get_hover_info() -> Resource:
	var info := HoverInfoDataScript.new()
	info.icon = hover_icon
	info.title = hover_title.strip_edges()
	if info.title.is_empty():
		info.title = display_name
	info.description = hover_description.strip_edges()
	info.footer = hover_footer.strip_edges()
	info.keyword_ids.append_array(hover_keywords)
	info.fields.append_array(hover_fields)
	info.panel_style = &"combatant"
	return info
