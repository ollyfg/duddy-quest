extends GutTest
## Regression tests for RoomPathfinder (scripts/pathfinder.gd).

const PathfinderScript = preload("res://scripts/pathfinder.gd")

## Node2D helper used to access the 2-D physics world from a plain Node test.
var _scene_node: Node2D


func before_each() -> void:
	_scene_node = Node2D.new()
	add_child_autoqfree(_scene_node)


## Build a pathfinder against the current (empty) physics space so all cells
## are treated as open — no static geometry is present in the test scene.
func _make_pathfinder(origin: Vector2 = Vector2.ZERO) -> Object:
	var pf: Object = PathfinderScript.new()
	pf.build(_scene_node.get_world_2d().direct_space_state, origin)
	return pf


# ---------------------------------------------------------------------------
# Basic direction tests
# ---------------------------------------------------------------------------

func test_get_next_direction_returns_normalized_vector() -> void:
	var pf: Object = _make_pathfinder()
	var dir: Vector2 = pf.get_next_direction(Vector2(8.0, 8.0), Vector2(200.0, 8.0))
	assert_ne(dir, Vector2.ZERO, "Should return a non-zero direction when path exists")
	assert_almost_eq(dir.length(), 1.0, 0.01, "Direction must be normalised")


func test_get_next_direction_zero_when_at_target() -> void:
	var pf: Object = _make_pathfinder()
	# from_world == to_world → no movement needed.
	var dir: Vector2 = pf.get_next_direction(Vector2(8.0, 8.0), Vector2(8.0, 8.0))
	assert_eq(dir, Vector2.ZERO, "Should return ZERO when already at target")


# ---------------------------------------------------------------------------
# Regression: near-cell-boundary freeze (southward movement)
# ---------------------------------------------------------------------------
# When travelling south, from_world can end up within 1 px of path[1] while
# still inside the current cell.  The old code returned Vector2.ZERO in that
# case, freezing both NPC chase and cinematic player movement indefinitely.

func test_get_next_direction_near_south_cell_boundary_not_zero() -> void:
	var pf: Object = _make_pathfinder()
	# from_world = (0.3, 15.8) → inside cell (0,0) (top-left at (0,0)).
	# path[1] will be cell (0,1) at world pos (0, 16).
	# dir = (0,16) − (0.3, 15.8) = (−0.3, 0.2) → length² = 0.13 < 1.0.
	# Before the fix this returned ZERO; after the fix it must advance to path[2]
	# or fall back to the direct direction toward to_world.
	var dir: Vector2 = pf.get_next_direction(Vector2(0.3, 15.8), Vector2(0.0, 40.0))
	assert_ne(dir, Vector2.ZERO,
		"get_next_direction must not freeze when from_world is within 1px of path[1] "
		+ "during southward movement (regression for near-cell-boundary bug)")
	assert_gt(dir.y, 0.0, "Direction should have a southward (positive-y) component")


func test_get_next_direction_near_east_cell_boundary_not_zero() -> void:
	var pf: Object = _make_pathfinder()
	# Similar regression for eastward movement.
	# from_world = (15.8, 0.3) → inside cell (0,0); path[1] = (16, 0).
	# dir = (0.2, −0.3) → length² = 0.13 < 1.0 (old code returned ZERO).
	var dir: Vector2 = pf.get_next_direction(Vector2(15.8, 0.3), Vector2(40.0, 0.0))
	assert_ne(dir, Vector2.ZERO,
		"get_next_direction must not freeze when from_world is within 1px of path[1] "
		+ "during eastward movement")
	assert_gt(dir.x, 0.0, "Direction should have an eastward (positive-x) component")


func test_get_next_direction_one_cell_south_near_boundary_not_zero() -> void:
	var pf: Object = _make_pathfinder()
	# to_world only one cell away; path has exactly 2 entries.
	# path[1] = (0,16); from_world = (0.3, 15.8) → dir=(−0.3,0.2), length²<1.
	# Fallback must use direct direction to to_world instead of returning ZERO.
	var dir: Vector2 = pf.get_next_direction(Vector2(0.3, 15.8), Vector2(0.0, 17.0))
	assert_ne(dir, Vector2.ZERO,
		"Single-step southward path near cell boundary must not freeze")
