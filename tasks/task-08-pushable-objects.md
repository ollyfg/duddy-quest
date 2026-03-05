# Task 08 — Pushable Objects

## Summary
Implement a pushable block node that the player can shove in a cardinal
direction by walking into it.  The block slides one grid step at a time and
stops if there is a wall or another solid object in the way.

---

## Motivation (from the plot)

- **Level 2 — Madam Malkin's:** Rotating mannequins knock Dudley off-course.
  While these are more like moving obstacles than pushable blocks, the same
  primitive is used for placing/arranging objects in a room.
- **Level 4 — The Giant Chess Board:** The player directs the surviving white
  chess pieces (rook and bishop) by pushing them to their required squares.
  The pieces must only move in legal chess directions: rook moves
  horizontally/vertically any number of squares; bishop moves diagonally.
  Successfully placing both pieces in the checkmating positions triggers the
  exit door to open.

---

## Acceptance Criteria

### Pushable Block

1. A new scene `scenes/pushable_block.tscn` with root `CharacterBody2D` and
   script `scripts/pushable_block.gd`.
   - 16 × 16 px collision shape (one grid cell) with a `ColorRect` sprite.
   - `@export var sprite_color: Color = Color(0.6, 0.6, 0.6)`
   - `@export var push_sound: AudioStream = null` (optional SFX).

2. When the player walks into a pushable block, the block slides **one grid
   step** (16 px) in the direction the player is moving, provided the cell in
   that direction is unoccupied (no `StaticBody2D` or other `CharacterBody2D`
   collision).

3. The block uses `move_and_slide()` for the slide animation so it respects
   walls.  If `move_and_slide()` results in zero displacement (hit a wall), the
   block stays put and the player is also stopped (the player cannot walk
   through an immovable block).

4. The block emits `signal pushed(new_position: Vector2)` after each successful
   push.

5. Add the block to the `"pushable"` group so puzzle scripts can query all
   pushable blocks in a room.

### Chess Piece Variant

6. A `chess_piece.tscn` (or exported property on the pushable block) restricts
   legal push directions:
   - `@export var piece_type: String = "free"` — values: `"free"`, `"rook"`,
     `"bishop"`, `"king"` (extend as needed).
   - When `piece_type == "rook"` only horizontal/vertical pushes are allowed.
   - When `piece_type == "bishop"` only diagonal pushes are allowed.
   - Illegal pushes do nothing (player stops at the piece, piece does not move).

7. A helper function `get_grid_position() -> Vector2i` returns the block's
   position as a chess-grid coordinate (divide world position by `GRID_SIZE`).

### Puzzle Trigger

8. A new scene `scenes/push_puzzle_trigger.tscn` with script
   `scripts/push_puzzle_trigger.gd`:
   - `@export var required_blocks: Array[NodePath]` — paths to pushable blocks.
   - `@export var required_positions: Array[Vector2]` — world-space target
     positions for each block.
   - Each frame (or on `pushed` signal), checks whether every listed block is
     within 4 px of its required position.
   - When all conditions are met, emits `signal puzzle_solved`.
   - `main.gd` can connect `puzzle_solved` to open a door, trigger a cutscene,
     etc.

---

## Implementation Notes

- The grid-step push animation can be a simple tween over ~0.15 s so it feels
  snappy.
- The player's `_physics_process` already does a wall-collision snap-back;
  pushable blocks must also participate in Godot's physics layer so the player's
  `move_and_slide()` detects them.  Assign pushable blocks to physics layer 2
  (or whichever layer the player checks for collisions) and add them to a
  `"pushable"` group.
- Chess piece movement restriction: in the player's push logic, check the piece
  type and the push direction before sliding.

---

## Dependencies

None.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scenes/pushable_block.tscn` | Create |
| `scripts/pushable_block.gd` | Create |
| `scenes/push_puzzle_trigger.tscn` | Create |
| `scripts/push_puzzle_trigger.gd` | Create |
| `scripts/player.gd` | Detect and push blocks in movement step |
