# Task 06 — Level Completion Mechanisms

## Summary
Implement the ability to mark a level as complete, display a level-complete
screen, and advance the player to the next level (or to the level-select
screen).  Also add a generic "level end trigger" zone that fires when the
player steps into it.

---

## Motivation (from the plot)

Each level has a defined endpoint:

- **Level 1:** Dudley boards the (wrong) bus — stepping into the bus-stop zone
  ends the level.
- **Level 2:** Dudley heads for King's Cross — reaching the station exit ends
  the level.
- **Level 3:** The Maintenance Express arrives at Hogwarts — stepping off the
  platform ends the level.
- **Level 4:** Defeating Quirrell / Voldemort and meeting Dumbledore ends the
  level; a cutscene and the Sorting Hat epilogue follow before returning to a
  credits/level-select screen.

---

## Acceptance Criteria

### Level End Trigger

1. A new scene `scenes/level_end_trigger.tscn` with script
   `scripts/level_end_trigger.gd`.
   - Root node: `Area2D`.
   - `@export var end_cutscene_slides: Array = []` — optional cutscene slides
     to play (uses Task 01 system) before the level-complete screen.
   - `@export var next_level: String = ""` — name of the next level defined in
     `main.gd` LEVELS dict; empty means return to level-select.
   - Emits `signal level_end_reached` when the player enters.

2. `main.gd` connects `level_end_reached` for any `LevelEndTrigger` nodes
   found in the room (or a dedicated `LevelEndTriggers` group).  On trigger:
   a. Freeze player input (`player.cinematic_mode = true`).
   b. Play `end_cutscene_slides` if non-empty (Task 01).
   c. Show the level-complete screen (see below).
   d. After dismissal advance to `next_level` or level-select.

### Level Complete Screen

3. A new scene `scenes/level_complete.tscn` with script
   `scripts/level_complete.gd`:
   - Full-screen overlay (CanvasLayer layer = 25).
   - Shows "LEVEL COMPLETE" text and the level's title.
   - Optional flavour text (short quote from the plot).
   - A "Continue" button (or any button press) dismisses it.
   - Emits `signal continue_pressed`.

4. `GameState` autoload (`scripts/game_state.gd`) gains:
   ```gdscript
   var completed_levels: Array[String] = []
   func mark_complete(level_name: String) -> void
   func is_complete(level_name: String) -> bool
   ```
   Completed levels unlock the next entry in the level-select menu.

### Level Select Integration

5. `level_select.gd` already shows level entries; extend it to grey out /
   lock levels whose prerequisite is not yet complete.  The "training" level
   is always unlocked.  Level 1 unlocks after training (or is always unlocked
   if training is treated as a tutorial).  Each subsequent level unlocks after
   the previous is complete.

### LEVELS Dictionary Update

6. Add an optional `"next_level"` key to each entry in the `LEVELS` dict in
   `main.gd` so level chaining can be configured centrally:
   ```gdscript
   "training": { ..., "next_level": "level_1" },
   "level_1":  { ..., "next_level": "level_2" },
   ...
   ```

---

## Implementation Notes

- The level-complete screen is distinct from the game-over overlay that
  already exists in `main.gd`.
- Boss-defeat completion (Level 4) is triggered by the boss dying, not by the
  player walking into a zone.  The boss script should emit a signal that
  `main.gd` catches and feeds into the same level-completion path.
- Cutscene slides for level-end use the Task 01 system.

---

## Dependencies

- Task 01 (cutscene system) for end-of-level cutscene slides.
- Task 07 (boss phases) for boss-defeat trigger in Level 4.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scenes/level_end_trigger.tscn` | Create |
| `scripts/level_end_trigger.gd` | Create |
| `scenes/level_complete.tscn` | Create |
| `scripts/level_complete.gd` | Create |
| `scripts/game_state.gd` | Add `completed_levels` tracking |
| `scripts/level_select.gd` | Gate locked levels |
| `scripts/main.gd` | Wire level-end triggers + completion flow |
