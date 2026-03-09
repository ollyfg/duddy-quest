# Level 2 Task 9 — Level 2 cutscenes (intro and outro)

## Context

Level 2 needs bookend cutscenes using the existing slide-show cutscene
system (`cutscene.gd` / `cutscene.tscn`). The intro sets the scene as
Dudley arrives at the Leaky Cauldron; the outro wraps up with him heading
to King's Cross.

## Requirements

### Intro cutscene (plays before `l2_leaky_cauldron` loads)

Slides (text + background colour):

| # | Text | Background |
|---|---|---|
| 1 | "After escaping Privet Drive, Dudley found himself on a London street he didn't recognise." | Dark grey `#2a2a2a` |
| 2 | "A grubby pub sign read 'The Leaky Cauldron'. Nobody else seemed to notice it." | Dark grey `#2a2a2a` |
| 3 | "Dudley barged inside, looking for a toilet." | Dark brown `#3a2a1a` |
| 4 | "Instead, he found something far stranger." | Black `#000000` |

### Outro cutscene (plays after Draco is defeated and level end trigger)

Slides:

| # | Text | Background |
|---|---|---|
| 1 | "Wand in his pocket and robes under his arm, Dudley left Diagon Alley behind." | Dark blue `#1a1a3a` |
| 2 | "He still wasn't sure how a wand had chosen HIM, of all people." | Dark blue `#1a1a3a` |
| 3 | "But the maple wand felt warm in his hand. Like it belonged there." | Warm gold `#3a2a0a` |
| 4 | "Next stop: King's Cross Station. Platform Nine and Three-Quarters." | Black `#000000` |

### Implementation

- Reuse the existing `play_cutscene()` method in `main.gd`
- Intro: called from `_load_level("level_2")` before loading the first
  room (same pattern as Level 1's cutscene)
- Outro: called from `_on_level_end_reached()` when the level is
  `"level_2"` (same pattern as Level 1's end)
- Slide data should be defined as a constant array in the `LEVELS`
  dictionary or a companion data file

### Level-complete flow
- After outro cutscene → show `level_complete.tscn` overlay
- Mark `level_2` as complete in `GameState`
- Return to level select (no Level 3 yet)

## Acceptance criteria

- [ ] Intro cutscene plays on starting Level 2
- [ ] Outro cutscene plays after defeating Draco and reaching level end
- [ ] Both cutscenes advance with `melee_attack` input
- [ ] Level marked complete in `GameState` after outro
- [ ] Player returns to level select after completion
- [ ] Cutscene text is readable and atmospheric
