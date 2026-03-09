# Level 2 Task 3 — Diagon Alley street rooms (south & north)

## Context

Diagon Alley is the main hub connecting all Level 2 shops. It's split into
two connected street sections so each fits in a standard room viewport.
The streets are lively and disorienting — crooked buildings, hanging shop
signs, and wandering wizard NPCs.

## Requirements

### `l2_diagon_alley_south.tscn`
- West exit → `l2_leaky_cauldron`
- East exit → `l2_gringotts`
- North exit → `l2_diagon_alley_north`
- Decorative elements: crooked building facades, shop signs, wandering
  wizard NPCs (friendly, flavour dialog only)
- 1–2 wandering wizard NPCs with random dialog pools:
  - "Mind the pixies, they've been dreadful this week."
  - "Gringotts is east. Don't let the goblins short-change you!"
  - "New student, are you? Good luck at Hogwarts."

### `l2_diagon_alley_north.tscn`
- South exit → `l2_diagon_alley_south`
- West exit → `l2_madam_malkins`
- East exit → `l2_ollivanders` (initially **locked** — requires Gringotts
  money flag `l2_has_wizard_money`)
- North exit → `l2_alley_end`
- The locked exit to Ollivander's should show a dialog:
  "You'll need wizard money before the shops will serve you."
- After the flag is set, the exit unlocks automatically
- 1–2 wandering wizard NPCs with different dialog pools

### Street ambiance
- Owl perch decorations (static sprites)
- Cauldron shop sign hanging at an angle
- Cobblestone floor tilemap

## Acceptance criteria

- [ ] Both rooms load and connect correctly in all directions
- [ ] Locked exit shows message and blocks until flag is set
- [ ] Wandering NPCs stay within room bounds
- [ ] `check_rooms.py` validates all connections are symmetric
- [ ] `check_alignment.py` passes
