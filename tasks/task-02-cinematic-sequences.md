# Task 02 — Scripted Cinematic Sequences (Non-Interactive)

## Summary
Implement a "cinematic mode" in which the player's controls are locked and a
pre-scripted sequence of NPC movements and dialog plays out automatically.
The player watches but cannot intervene.  Once the sequence ends, control
returns to normal gameplay.

---

## Motivation (from the plot)

Several story moments require NPCs (and sometimes the player character) to move
and speak without any player input:

- **Level 1:** Petunia intercepts Dudley; the letter scene.
- **Level 2:** Lucius watches the Draco fight from a distance; Ollivander
  emerges from his shop and hands Dudley the wand.
- **Level 3:** Fred and George cheerfuly wave Dudley onto the wrong platform;
  the train arrives.
- **Level 4:** Dumbledore arrives after the Quirrell fight; the Sorting Hat
  ceremony epilogue.

---

## Acceptance Criteria

1. A `CinematicSequence` resource (or plain Dictionary spec) describes a list of
   *steps*.  Each step is one of:
   - `{ "type": "move_npc", "npc": <node_path>, "to": Vector2, "speed": float }`
   - `{ "type": "move_player", "to": Vector2, "speed": float }`
   - `{ "type": "dialog", "speaker": <node_path or "narrator">, "lines": Array[String] }`
   - `{ "type": "wait", "duration": float }`
   - `{ "type": "play_cutscene", "slides": Array }` — delegates to the
     cutscene system (Task 01).
   Steps execute sequentially; `move` steps for *different* nodes may be
   flagged `"parallel": true` to run simultaneously.

2. A new autoload or helper node `CinematicPlayer` (script
   `scripts/cinematic_player.gd`) executes sequences:
   ```gdscript
   signal sequence_finished
   func play(sequence: Array, room: Node, player: Node) -> void
   ```

3. While a cinematic is playing:
   - All player input (movement + combat) is ignored (`player.cinematic_mode =
     true`).
   - NPCs involved in the sequence have their normal AI suspended.
   - The existing dialog box (`dialog_box.gd`) is reused for in-cinematic
     dialog lines; the player advances those lines normally.

4. `player.gd` gains a `cinematic_mode: bool` property.  When `true`,
   `_physics_process` skips all input reading and movement (equivalent to
   `is_in_dialog` but for full cinematics).

5. `main.gd` gains:
   ```gdscript
   func play_cinematic(sequence: Array, on_finish: Callable) -> void
   ```

6. A simple integration test / demonstration: after entering `room_a` for the
   first time, a one-step cinematic plays in which the friendly NPC says a single
   line of dialog, then control returns.  (Remove the demo once real cinematics
   are wired up.)

---

## Implementation Notes

- NPC node paths in a sequence step are relative to the room root (e.g.
  `"NPCs/GreeterNPC"`).
- Movement steps use `move_toward` each `_process` tick so the entity moves
  smoothly and obeys walls via `move_and_slide`.
- Dialog during cinematics should auto-advance after a configurable delay
  *or* on button press — expose `auto_advance_delay: float = 0.0` (0 = wait
  for button).

---

## Dependencies

- Task 01 (cutscene system) for the `play_cutscene` step type.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scripts/cinematic_player.gd` | Create |
| `scripts/player.gd` | Add `cinematic_mode` property |
| `scripts/main.gd` | Add `play_cinematic()` helper |
| `project.godot` | Register `CinematicPlayer` as autoload (if desired) |
