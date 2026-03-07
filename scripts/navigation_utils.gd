extends RefCounted

## Shared short-range steering helper used by AI and cinematic movement.
const LOOK_AHEAD: float = 40.0
const STEER_ANGLES: Array[int] = [30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180]


static func navigate_toward(
	position: Vector2,
	target: Vector2,
	space: PhysicsDirectSpaceState2D,
	exclude_rids: Array[RID]
) -> Vector2:
	var to_target: Vector2 = target - position
	if to_target.length_squared() < 1.0:
		return Vector2.ZERO
	var desired_dir: Vector2 = to_target.normalized()

	var q := PhysicsRayQueryParameters2D.create(
		position, position + desired_dir * LOOK_AHEAD)
	q.exclude = exclude_rids
	if space.intersect_ray(q).is_empty():
		return desired_dir

	var best_dir: Vector2 = desired_dir
	var best_score: float = -INF
	for angle_deg: int in STEER_ANGLES:
		var test_dir: Vector2 = desired_dir.rotated(deg_to_rad(float(angle_deg)))
		var qt := PhysicsRayQueryParameters2D.create(
			position, position + test_dir * LOOK_AHEAD)
		qt.exclude = exclude_rids
		if space.intersect_ray(qt).is_empty():
			var score: float = test_dir.dot(desired_dir)
			if score > best_score:
				best_score = score
				best_dir = test_dir
	return best_dir
