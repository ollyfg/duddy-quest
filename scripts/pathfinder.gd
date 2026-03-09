class_name RoomPathfinder
extends RefCounted

## Grid cell size in pixels — must match the project's 16-px layout grid.
const CELL_SIZE: int = 16

var _astar: AStarGrid2D = null
var _room_origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0


## Build the A* grid by scanning `space` for StaticBody2D obstacles.
## `room_origin` is the global_position of the Room node; `room_size` is the
## pixel dimensions of the room (defaults to 640×480 for backward compatibility).
## The path points returned by get_next_direction() are in the same world
## coordinate space as the NPC's global_position.
func build(space: PhysicsDirectSpaceState2D, room_origin: Vector2 = Vector2.ZERO, room_size: Vector2 = Vector2(640.0, 480.0)) -> void:
	_room_origin = room_origin
	_cols = max(1, ceili(room_size.x / CELL_SIZE))
	_rows = max(1, ceili(room_size.y / CELL_SIZE))
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _cols, _rows)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	# Setting offset to room_origin makes get_point_path() return world-space
	# positions directly, matching the NPC's global_position coordinate space.
	_astar.offset = room_origin
	# Cardinal-only movement is simpler and avoids corner-cutting artefacts.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	# Scan every cell and mark those containing static obstacle geometry solid.
	for row in range(_rows):
		for col in range(_cols):
			var cell_center: Vector2 = room_origin + Vector2(
				col * CELL_SIZE + CELL_SIZE * 0.5,
				row * CELL_SIZE + CELL_SIZE * 0.5
			)
			var q := PhysicsPointQueryParameters2D.new()
			q.position = cell_center
			# Scan all layers; only StaticBody2D hits are treated as obstacles.
			q.collision_mask = 0xFFFFFFFF
			var results: Array = space.intersect_point(q)
			for result: Dictionary in results:
				if result["collider"] is StaticBody2D:
					_astar.set_point_solid(Vector2i(col, row), true)
					break


## Returns a normalised direction from `from_world` toward `to_world` using
## A* to route around static obstacles.  Falls back to the direct direction
## when the grid has not been built or no path exists.
func get_next_direction(from_world: Vector2, to_world: Vector2) -> Vector2:
	if _astar == null:
		var fallback: Vector2 = to_world - from_world
		if fallback.length_squared() < 1.0:
			return Vector2.ZERO
		return fallback.normalized()

	var from_cell: Vector2i = _world_to_cell(from_world)
	var to_cell: Vector2i = _world_to_cell(to_world)
	# Clamp to valid grid bounds.
	from_cell = from_cell.clamp(Vector2i.ZERO, Vector2i(_cols - 1, _rows - 1))
	to_cell = to_cell.clamp(Vector2i.ZERO, Vector2i(_cols - 1, _rows - 1))

	# If the start cell is solid (e.g. NPC spawned inside geometry), go direct.
	if _astar.is_point_solid(from_cell):
		var fallback: Vector2 = to_world - from_world
		if fallback.length_squared() < 1.0:
			return Vector2.ZERO
		return fallback.normalized()

	# allow_partial_path = true so that even if the target is inside a solid
	# cell (e.g. player standing against a wall) we still get a useful path.
	var path: PackedVector2Array = _astar.get_point_path(from_cell, to_cell, true)
	if path.size() < 2:
		var fallback: Vector2 = to_world - from_world
		if fallback.length_squared() < 1.0:
			return Vector2.ZERO
		return fallback.normalized()

	# path[0] is the top-left of the current cell; path[1] is the next waypoint.
	# Both are in world space because _astar.offset = _room_origin.
	# Skip waypoints that are already within 1 px of the current position to
	# avoid a near-zero direction vector that stalls movement near cell boundaries
	# (e.g. when travelling south and from_world is very close to path[1]).
	for i: int in range(1, path.size()):
		var dir: Vector2 = path[i] - from_world
		if dir.length_squared() >= 1.0:
			return dir.normalized()
	# All remaining waypoints are within 1 px; fall back to direct direction.
	var fallback: Vector2 = to_world - from_world
	if fallback.length_squared() < 1.0:
		return Vector2.ZERO
	return fallback.normalized()


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - _room_origin
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))
