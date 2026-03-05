# Task 04 — Multi-Option Branching Dialogue Trees

## Summary
Extend the existing `dialog_box.gd` / `dialog_box.tscn` to support dialogue
trees: nodes that present the player with two or more selectable response
options, leading to different branches of conversation.

---

## Motivation (from the plot)

Several key interactions in the levels require the player to make choices:

- **Level 1 — Mrs. Figg's cats:** The player must identify which cat is
  Mr Tibbles by selecting descriptors from a list.  (Effectively a multi-choice
  question with a right and wrong answer.)
- **Level 2 — Gringotts goblin:** Dudley makes a series of arguments; the
  player picks the most convincing ones in order until the goblin relents.
- **Level 4 — Potions puzzle:** The player selects which bottle to drink from
  a numbered list.

Plain linear dialog lines are not enough for these encounters.

---

## Acceptance Criteria

### Data Format

Dialog lines may be either:

- **A plain `String`** — displayed as before, advanced with a button press.
- **A `Dictionary`** with:
  ```gdscript
  {
    "text": String,          # NPC/narrator text to show first
    "options": Array,        # list of option Dictionaries
  }
  ```
  Each option Dictionary:
  ```gdscript
  {
    "label": String,         # text shown on the choice button
    "next": Array,           # sub-sequence of lines/dicts to play on selection
    # Optional:
    "correct": bool,         # if true: emit choice_correct signal on selection
    "outcome": String,       # arbitrary tag emitted with choice_made signal
  }
  ```

### UI

- When a choice node is reached, the dialog panel expands to show the NPC's
  prompt text above a vertically stacked list of option buttons (maximum 4).
- The player navigates options with `move_up` / `move_down` (keyboard/D-pad)
  and confirms with `melee_attack` or `ranged_attack`, **or** clicks/taps the
  button directly.
- Mobile: option buttons must be large enough to tap (min 44 px height).

### Signals

`dialog_box.gd` gains two new signals:
```gdscript
signal choice_made(outcome: String)   # fired when any option is chosen
signal choice_correct                 # fired when an option marked correct: true is chosen
```

### Backward Compatibility

All existing callers of `start_dialog(lines: Array)` continue to work without
modification.  Plain `String` entries in the array are handled exactly as
before.

### Example

```gdscript
var figg_dialog = [
    "Now, which one is Mr Tibbles?  He's a tabby, has a notched left ear, and " +
    "always wears a blue collar.",
    {
        "text": "Point to the cat you think is Mr Tibbles.",
        "options": [
            { "label": "The ginger one by the roses",   "next": ["That's Snowy, dear."],       "correct": false },
            { "label": "The tabby with the blue collar","next": ["Yes! That's Mr Tibbles!"], "correct": true, "outcome": "figg_cat_found" },
            { "label": "The big fluffy one",            "next": ["Oh no, that's Mr Whiskers."], "correct": false },
        ]
    }
]
```

---

## Implementation Notes

- Keep `dialog_box.gd` as the single entry point; do not create a separate
  scene.
- Option buttons can be `Button` nodes added dynamically and freed after the
  choice is made.
- Nest branches by recursively calling an internal `_start_sequence(lines)`
  method so the post-choice `next` array flows naturally into the remaining
  outer dialog.
- Keep the "Press any button to continue" hint visible only when no options are
  showing.

---

## Dependencies

None.

---

## Files to Modify

| File | Action |
|------|--------|
| `scripts/dialog_box.gd` | Extend with option rendering + navigation |
| `scenes/dialog_box.tscn` | Add option button container (VBoxContainer) |
