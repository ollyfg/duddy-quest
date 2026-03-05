# Task 09 — Light Sources and Light-Reactive Entities

## Summary
Add a `LightSource` node that illuminates a circular radius around itself, and
implement entities that react to whether they are in light or darkness.  The
primary use is the **Devil's Snare puzzle** in Level 4, where the player must
light torches in sequence to open safe corridors through a light-hating vine.

---

## Motivation (from the plot — Level 4)

> **Devil's Snare:** The vine recoils from light.  Scattered around the room are
> stone braziers with unlit torches; each torch, once lit with a wand-blast,
> illuminates a safe corridor through the plant for a few seconds before
> guttering out.  The puzzle is timing — light the torches in the right sequence
> and sprint through the gaps before the vine closes back in.

The same system can be used for any future light/dark mechanics (e.g. a room
that needs Lumos, or enemies that only activate in darkness).

---

## Acceptance Criteria

### LightSource Node

1. A new scene `scenes/light_source.tscn` with script `scripts/light_source.gd`.
   - Root: `Node2D`.
   - `@export var radius: float = 80.0` — illumination radius in pixels.
   - `@export var duration: float = 0.0` — if > 0, the light automatically goes
     out after this many seconds.  0 = permanent.
   - `@export var starts_lit: bool = false`.
   - `@export var lit_color: Color = Color(1.0, 0.85, 0.4, 0.35)` — colour of
     the visual glow overlay.
   - A `PointLight2D` child provides the visual glow (texture: a soft radial
     gradient; energy driven by `radius` and on/off state).
   - Public API:
     ```gdscript
     signal lit_changed(is_lit: bool)
     func light_up() -> void    # turns the light on (resets duration timer)
     func extinguish() -> void  # turns it off
     var is_lit: bool
     ```

2. A `LightSource` can be **lit by a wand-blast** by adding it to the
   `"lightable"` group and implementing `on_hit()`:
   ```gdscript
   func on_hit() -> void:
       light_up()
   ```
   The player's melee-area already calls `on_hit()` on bodies it overlaps; the
   projectile script should also call `on_hit()` on nodes it collides with.

3. A static helper `LightSource.is_point_lit(point: Vector2, scene_tree:
   SceneTree) -> bool` iterates all nodes in the `"light_source"` group and
   returns `true` if `point` is within the `radius` of any lit source.

### Devil's Snare Entity

4. A new scene `scenes/devils_snare.tscn` with script `scripts/devils_snare.gd`.
   - Root: `Area2D` (covers the vine's area on screen).
   - `@export var open_exit_on_clear: bool = false` — if true, all vine segments
     being retracted opens a linked exit or door.
   - The vine is represented by a tiling `ColorRect` or `Sprite2D` that fills
     the room until cleared.
   - Each `_physics_process` tick the vine checks
     `LightSource.is_point_lit(global_position, get_tree())`.
   - If lit: the vine recoils (a retract animation: shrink/fade the blocking
     area or move the vine obstacle).  The vine remains open for as long as a
     light source covers it.
   - If dark again: the vine grows back (re-expands).
   - While open, the vine's `CollisionShape2D` is disabled so the player can
     pass through.
   - While closed, the vine's `CollisionShape2D` blocks the player.

5. Individual vine **segments** (multiple `DevilsSnare` nodes placed in a room)
   each independently check their own position; this allows one torch to open
   only the vine segments within its radius.

### Torch Brazier (Placeable Object)

6. A new scene `scenes/torch.tscn` (root `Node2D`) that combines:
   - A `LightSource` child (with `duration` configurable).
   - A `StaticBody2D` with collision so the player cannot walk through it.
   - A `ColorRect` sprite showing an unlit (grey) or lit (orange/yellow) state,
     driven by `lit_changed`.
   - Is in group `"lightable"` so wand blasts and ranged projectiles can light it.

---

## Implementation Notes

- `PointLight2D` in Godot 4 requires a texture; use a small programmatically-
  generated `GradientTexture2D` (white centre → transparent edge) so no art
  asset is needed immediately.
- The `is_point_lit` helper iterates the group; for a small number of light
  sources this is fine. Do not over-engineer.
- Projectile collision: `projectile.gd` already handles `take_damage`; add
  `on_hit()` call for non-damageable nodes it hits (nodes in `"lightable"`
  group).
- The Devil's Snare vine overlay should be on a CanvasLayer or drawn as a
  TileMap; for simplicity, a `ColorRect` that covers the vine area and whose
  modulate alpha is tweened in/out is sufficient.

---

## Dependencies

- Task 07 (boss phases) — not strictly needed, but wand-blast collision
  improvements in projectile.gd are shared.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scenes/light_source.tscn` | Create |
| `scripts/light_source.gd` | Create |
| `scenes/devils_snare.tscn` | Create |
| `scripts/devils_snare.gd` | Create |
| `scenes/torch.tscn` | Create |
| `scripts/torch.gd` | Create (or inline in torch.tscn) |
| `scripts/projectile.gd` | Call `on_hit()` for lightable nodes |
