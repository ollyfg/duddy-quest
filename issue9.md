# Issue 9 — Remove hardcoded room-size assumptions (640×480)

## Problem

Multiple scripts assume every room is exactly 640 × 480 pixels:

| File | Line(s) | Usage |
|---|---|---|
| `npc.gd` | 120–121 | `ROOM_BOUNDS_MIN/MAX` used for wander clamping |
| `room.gd` | 20 | `room_size` default `Vector2(640, 480)` |
| `level_select.gd` | 25 | `bg.size = Vector2(640, 480)` |
| `main.gd` | ~235 | Camera limits set from `current_room.room_size` (OK — but callers also hardcode) |
| `cinematic_player.gd` | 7 | `UNLIMITED_CAMERA_LIMIT = 100000` (works but magic) |

Level 2's Diagon Alley is likely to have wider or taller rooms (e.g. a
scrolling street scene). If any room exceeds 640 × 480 the NPC wander
bounds, camera limits, and UI backgrounds will be wrong.

## Suggested approach

1. Make `room.gd` the authoritative source: every room exports its own
   `room_size` in the scene inspector (already started — default is
   `Vector2(640, 480)`).
2. NPC wander bounds should read from the room, not from a constant.
   Pass room bounds to NPCs during `_load_room()` or let NPCs query
   their parent room.
3. Remove or replace the `ROOM_BOUNDS_*` constants in `npc.gd`.
4. `UNLIMITED_CAMERA_LIMIT` can be replaced by the actual room size
   plus a margin.
5. `level_select.gd` should read the viewport size, not hardcode
   `640 × 480`.

## Acceptance criteria

- [ ] No script contains a hardcoded `640` or `480` room assumption
- [ ] A test room wider than 640px works correctly (NPC wander stays
      in bounds, camera scrolls properly)
- [ ] Existing 640×480 rooms are unaffected
