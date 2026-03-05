# Task 01 — Full-Screen Cutscene / Narration Panel System

## Summary
Implement a full-screen cutscene system that displays one or more slides, each
containing an illustration and a block of text.  Cutscenes are used to set the
scene before a level begins, to recap story beats between major areas within a
level, and to play the level-end epilogue.  The player advances through slides
by pressing any action button (or tapping on mobile).

---

## Motivation (from the plot)

Every level in PLOT.md opens with a scene-setting story recap and ends with a
narrative beat (e.g. "Dudley boards the wrong bus…").  These moments need a
dedicated full-screen presentation mode that is richer than the existing small
dialog box but does not require live NPCs or gameplay.

---

## Acceptance Criteria

1. A new scene `scenes/cutscene.tscn` with script `scripts/cutscene.gd` exists.
2. A `CutsceneSlide` resource type (or Dictionary spec) carries:
   - `image: Texture2D` (may be `null` — show a plain coloured background)
   - `text: String`
   - `background_color: Color` (fallback when `image` is null; default black)
3. The cutscene fills the entire 640 × 480 viewport:
   - Upper ~60 % shows the image (or solid background).
   - Lower ~40 % shows a semi-transparent dark panel with the slide text.
   - A small "▶ Press any button to continue" hint is shown at the bottom right.
4. `cutscene.gd` exposes:
   ```gdscript
   signal cutscene_finished
   func play(slides: Array) -> void   # starts the sequence
   ```
5. Pressing `melee_attack`, `ranged_attack`, `interact`, or any directional input
   advances to the next slide.  After the last slide `cutscene_finished` is emitted.
6. The cutscene CanvasLayer sits on layer 30 so it appears above HUD, dialog
   boxes, and game-over overlays.
7. `main.gd` gains a helper:
   ```gdscript
   func play_cutscene(slides: Array, on_finish: Callable) -> void
   ```
   This instantiates (or shows) the cutscene node, plays the sequence, and calls
   `on_finish` when `cutscene_finished` fires.
8. An example cutscene (using null images and placeholder text) is triggered when
   the "training" level loads, just to prove the system works end-to-end.  It can
   be removed once real level cutscenes are added.

---

## Implementation Notes

- Use a `CanvasLayer` (layer = 30) as the root so it overlays everything.
- The text panel is a `Panel` + `Label` with autowrap enabled.
- Text should use the same font size conventions as the existing dialog box
  (see `scenes/dialog_box.tscn`).
- Keep slide data as plain `Array[Dictionary]` (keys: `image`, `text`,
  `background_color`) rather than a custom Resource to keep things simple.
- Slides array may be defined inline in GDScript or loaded from a data file —
  inline is fine for now.

---

## Dependencies

None — this is a standalone new feature.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scenes/cutscene.tscn` | Create |
| `scripts/cutscene.gd` | Create |
| `scripts/main.gd` | Add `play_cutscene()` helper |
