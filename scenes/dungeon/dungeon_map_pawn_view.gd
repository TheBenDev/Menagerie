## Displays one dungeon map pawn as a replaceable marker driven by run-owned pawn state.
class_name DungeonMapPawnView
extends Control

const DEFAULT_MARKER_DIAMETER := 26.0
const SMALL_NODE_ANCHOR_RATIO := Vector2(0.5, 0.5)
const LARGE_NODE_ANCHOR_RATIO := Vector2(0.27, 0.27)

@export var marker_color: Color = Color(0.20, 0.76, 1.0, 1.0)
@export var outline_color: Color = Color(0.03, 0.05, 0.07, 0.95)
@export var marker_diameter: float = DEFAULT_MARKER_DIAMETER

var pawn_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 10

## Initializes this marker from a pawn and its current node.
func configure(pawn: Variant, node_data: DungeonNodeData, cell_size: float) -> void:
	pawn_id = str(pawn.pawn_id) if pawn != null else ""
	apply_pawn_state(pawn, node_data, cell_size)

## Repositions and redraws this marker from authoritative pawn position state.
func apply_pawn_state(pawn: Variant, node_data: DungeonNodeData, cell_size: float) -> void:
	if pawn == null or node_data == null or int(pawn.current_node_id) != node_data.id:
		visible = false
		return

	visible = true
	var resolved_diameter: float = max(marker_diameter, 8.0)
	size = Vector2(resolved_diameter, resolved_diameter)
	custom_minimum_size = size
	position = marker_center_for_node(node_data, cell_size) - size * 0.5
	queue_redraw()

## Returns the marker center point in map-content coordinates for a node.
static func marker_center_for_node(node_data: DungeonNodeData, cell_size: float) -> Vector2:
	if node_data == null:
		return Vector2.ZERO

	var node_position: Vector2 = Vector2(node_data.grid_position) * cell_size
	var node_size: Vector2 = Vector2(node_data.grid_size) * cell_size
	var anchor_ratio: Vector2 = SMALL_NODE_ANCHOR_RATIO
	if node_data.grid_size.x > 1 or node_data.grid_size.y > 1:
		anchor_ratio = LARGE_NODE_ANCHOR_RATIO

	return node_position + node_size * anchor_ratio

func _draw() -> void:
	var radius: float = min(size.x, size.y) * 0.5
	if radius <= 0.0:
		return

	var center: Vector2 = size * 0.5
	draw_circle(center, radius, outline_color)
	draw_circle(center, max(radius - 3.0, 1.0), marker_color)
