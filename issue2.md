# Issue 2 — Consolidate game-state flags into a single dictionary

## Problem

`scripts/game_state.gd` tracks one-off story events in two incompatible
ways:

1. **Specific boolean variables** — `l1_bedroom_door_hint_shown`,
   `l1_hallway_intro_shown`, `l1_street_intro_shown`.
2. **Generic `flags` dictionary** — `set_flag()` / `has_flag()`.

Adding Level 2 will introduce 5–10 more story flags. If each one is a
dedicated `var`, the file becomes a dumping ground of per-level booleans
that can't be iterated, serialised, or reset as a group. Callers already
mix the two systems, so a future save/load feature would have to know
about both.

## Suggested approach

1. Remove the three `l1_*` booleans and migrate their users to
   `flags` dictionary calls:
   ```gdscript
   # Before
   GameState.l1_hallway_intro_shown = true
   # After
   GameState.set_flag("l1_hallway_intro_shown")
   ```
2. Add a `KNOWN_FLAGS` constant array listing every valid flag name.
   `set_flag()` should `push_warning` if the name is not in the list —
   this catches typos at dev time without crashing in release.
3. Add `clear_level_flags(prefix: String)` so level restarts can wipe
   all flags starting with e.g. `"l1_"`.

## Affected files

- `scripts/game_state.gd` — flag storage
- `scripts/main.gd` — reads/writes the `l1_*` booleans in
  `_load_room()`, `_play_hallway_intro()`, `_play_street_intro()`,
  `_on_bedroom_door_approached()`

## Acceptance criteria

- [ ] No dedicated per-level boolean variables remain in `game_state.gd`
- [ ] `set_flag()` warns on unknown flag names
- [ ] `clear_level_flags("l1_")` resets all Level 1 flags
- [ ] Existing GUT tests (`test_game_state.gd`) updated and passing
- [ ] Gameplay unchanged — verify with `playtest.py`
