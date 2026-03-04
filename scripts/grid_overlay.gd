extends Node2D

## Draws a transparent grid aligned to the world tile grid.
## Useful for verifying that sprites and NPCs are correctly grid-snapped.

const GRID_SIZE: int = 16
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	# Vertical lines
	var x: float = 0.0
	while x <= vp_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, vp_size.y), GRID_COLOR)
		x += GRID_SIZE
	# Horizontal lines
	var y: float = 0.0
	while y <= vp_size.y:
		draw_line(Vector2(0.0, y), Vector2(vp_size.x, y), GRID_COLOR)
		y += GRID_SIZE
