## Draws the dungeon map grid behind generated dungeon nodes.
class_name DungeonGridView
extends Control

@export var cell_size: float = 72.0
@export var columns: int = 1
@export var rows: int = 1
@export var line_color: Color = Color(0.64, 0.58, 0.48, 0.22)
@export var major_line_color: Color = Color(0.86, 0.78, 0.58, 0.34)

func configure(new_columns: int, new_rows: int, new_cell_size: float) -> void:
	columns = max(new_columns, 1)
	rows = max(new_rows, 1)
	cell_size = max(new_cell_size, 1.0)
	size = Vector2(float(columns) * cell_size, float(rows) * cell_size)
	custom_minimum_size = size
	queue_redraw()

func _draw() -> void:
	var grid_width := float(columns) * cell_size
	var grid_height := float(rows) * cell_size
	for column in range(columns + 1):
		var x := float(column) * cell_size
		var color := major_line_color if column % 3 == 0 else line_color
		draw_line(Vector2(x, 0.0), Vector2(x, grid_height), color, 1.0)

	for row in range(rows + 1):
		var y := float(row) * cell_size
		var color := major_line_color if row % 3 == 0 else line_color
		draw_line(Vector2(0.0, y), Vector2(grid_width, y), color, 1.0)
