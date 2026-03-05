# Task 03 — PATROL Movement Mode for NPCs

## Summary
Add a `PATROL` movement mode to `npc.gd` that makes an NPC walk between a
designer-specified list of waypoints in order, looping back to the start when
the last waypoint is reached.

---

## Motivation (from the plot)

Several characters and enemies in the levels follow fixed, repeating routes:

- **Level 1:** Aunt Petunia vacuums the landing on a strict timetable — she
  walks from room to room and back.  The player must time dashes through the
  gaps in her patrol route.
- **Level 1:** Ripper the bulldog patrols the garden.
- **Level 3:** The Trolley Witch walks the length of the train.
- **Level 4:** Mr Filch patrols the castle corridors.

A simple waypoint-based patrol covers all of these cases.

---

## Acceptance Criteria

1. `MovementMode` enum in `npc.gd` gains a new value: `PATROL` (add after the
   existing `KEEP_DISTANCE` entry so existing numeric values are unchanged).

2. A new export is added to `npc.gd`:
   ```gdscript
   ## Ordered list of world-space positions this NPC walks between when
   ## movement_mode is PATROL.  The NPC loops back to the first point after
   ## reaching the last one.
   @export var patrol_points: Array[Vector2] = []
   ```

3. When `movement_mode == MovementMode.PATROL` and `patrol_points` is
   non-empty, the NPC:
   - Moves toward `patrol_points[_patrol_index]` at `move_speed`.
   - When it is within 8 px of the current target, advances `_patrol_index`
     (wrapping with modulo) and optionally waits `patrol_pause_duration` seconds
     before moving to the next point.
   - If `patrol_points` is empty, the NPC stands still.

4. A new export controls the pause at each waypoint:
   ```gdscript
   ## Seconds to pause at each waypoint before moving to the next.
   @export var patrol_pause_duration: float = 0.0
   ```

5. If the NPC is hostile and `detection_range > 0`, encountering the player
   within detection range switches it from PATROL to CHASE for the duration of
   the encounter (same as the existing `idle_movement_mode` logic).  When the
   player leaves `detection_range`, the NPC resumes PATROL from the nearest
   waypoint.

6. In the Godot editor, patrol waypoints are most conveniently placed as
   `Marker2D` child nodes named `PatrolPoint0`, `PatrolPoint1`, etc.  Add a
   helper function that auto-populates `patrol_points` from such child nodes in
   `_ready()` if `patrol_points` is empty:
   ```gdscript
   func _collect_patrol_points_from_children() -> void:
       for child in get_children():
           if child is Marker2D and child.name.begins_with("PatrolPoint"):
               patrol_points.append(child.global_position)
   ```

7. Existing movement modes and unit tests are unaffected.

---

## Implementation Notes

- Internal state: add `var _patrol_index: int = 0` and
  `var _patrol_pause_timer: float = 0.0`.
- Patrol movement uses the same `velocity = direction.normalized() * move_speed`
  + `move_and_slide()` pattern used by CHASE.
- Do **not** change the integer values of existing `MovementMode` variants; only
  append at the end.

---

## Dependencies

None — this is a standalone addition to `npc.gd`.

---

## Files to Modify

| File | Action |
|------|--------|
| `scripts/npc.gd` | Add `PATROL` enum value, exports, and logic |
