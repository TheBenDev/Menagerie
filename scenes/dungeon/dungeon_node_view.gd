## Texture button view for a dungeon map node that displays node art, visibility, and visit state.
class_name DungeonNodeView
extends TextureButton

@export var node_id: int = -1
@export_enum("Empty", "Haven", "Fight", "Encounter", "Boss") var node_type: String = "Fight"
@export var grid_position: Vector2i = Vector2i.ZERO
@export var grid_size: Vector2i = Vector2i.ONE
@export var encounter_id: StringName = &""
@export var combat_encounter_id: StringName = &""
@export_file("*.tres") var combat_encounter_profile_path: String = ""
@export var is_boss: bool = false

const NODE_TEXTURE_PATHS := {
	"Empty": "res://assets/ui/dungeon/nodes/EmptyNode.png",
	"Haven": "res://assets/ui/dungeon/nodes/HavenNode.png",
	"Fight": "res://assets/ui/dungeon/nodes/FightNode.png",
	"Encounter": "res://assets/ui/dungeon/nodes/EncounterNode.png",
	"Boss": "res://assets/ui/dungeon/nodes/BossNode.png",
}

const NODE_HOVER_TEXTURE_PATHS := {
	"Empty": "res://assets/ui/dungeon/nodes/EmptyNode_hover.png",
	"Haven": "res://assets/ui/dungeon/nodes/HavenNode_hover.png",
	"Fight": "res://assets/ui/dungeon/nodes/FightNode_hover.png",
	"Encounter": "res://assets/ui/dungeon/nodes/EncounterNode_hover.png",
	"Boss": "res://assets/ui/dungeon/nodes/BossNode_hover.png",
}

func configure(data: DungeonNodeData, cell_size: float) -> void:
	node_id = data.id
	node_type = data.node_type
	grid_position = data.grid_position
	grid_size = data.grid_size
	encounter_id = data.encounter_id
	combat_encounter_id = data.combat_encounter_id
	combat_encounter_profile_path = data.combat_encounter_profile_path
	is_boss = data.is_boss
	position = Vector2(grid_position) * cell_size
	size = Vector2(grid_size) * cell_size
	custom_minimum_size = size
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	texture_normal = load(str(NODE_TEXTURE_PATHS.get(node_type, NODE_TEXTURE_PATHS["Encounter"])))
	texture_hover = load(str(NODE_HOVER_TEXTURE_PATHS.get(node_type, NODE_HOVER_TEXTURE_PATHS["Encounter"])))
	texture_pressed = texture_hover
	texture_disabled = texture_normal
	tooltip_text = ""

func apply_state(data: DungeonNodeData, is_current: bool, can_select: bool) -> void:
	if data == null:
		disabled = true
		visible = false
		return

	visible = data.revealed or data.visited
	disabled = not can_select
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_select else Control.CURSOR_ARROW
	if data.visited and is_current:
		modulate = Color(1.0, 0.95, 0.72, 1.0)
	elif data.resolved and can_select:
		modulate = Color(0.84, 0.88, 0.92, 0.92)
	elif data.visited:
		modulate = Color(0.68, 0.70, 0.72, 0.86)
	elif can_select:
		modulate = Color.WHITE
	else:
		modulate = Color(0.48, 0.50, 0.54, 0.78)
