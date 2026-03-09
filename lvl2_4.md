# Level 2 Task 4 — Gringotts money exchange puzzle

## Context

Dudley has Muggle birthday cash but needs wizard money. The Goblin Clerk
at Gringotts is deliberately obstructive — quoting a fraudulent exchange
rate, hiding the fee schedule, and turning the rate board to the wall.

This is a **dialog-based puzzle** — Dudley must argue logically to get a
fair deal. It introduces branching dialog with player choices.

## Requirements

### Room layout (`l2_gringotts.tscn`)
- Grand bank interior: marble columns, teller windows (obstacles)
- West exit → `l2_diagon_alley_south`
- No other exits

### Goblin Clerk NPC
- Friendly NPC (not hostile but not helpful), placed behind teller counter
- `npc_name`: `"Goblin Clerk"`
- **Multi-stage branching dialog:**

  **Stage 1** (first interaction, flag `l2_goblin_stage` not set):
  - "Exchange? Certainly. The rate is 3 Galleons per pound."
  - Options: `["That seems fair", "That can't be right"]`
  - "That seems fair" → Clerk takes all money, gives almost nothing,
    dialog ends with hint to try again
  - "That can't be right" → advances to Stage 2

  **Stage 2** (flag `l2_goblin_challenged`):
  - "The rate board? It's... being cleaned."
  - "Fine. The ACTUAL rate is 17 pounds to the Galleon."
  - "Processing fee of... let me find the schedule..."
  - Options: `["I can see it right there", "Take your time"]`
  - Correct answer advances to Stage 3

  **Stage 3** (flag `l2_goblin_caught`):
  - "...Very well. Standard rate. No extras."
  - Sets flag `l2_has_wizard_money`
  - Goblin becomes passive (repeat dialog: "Is there anything else?")

### Post-puzzle
- After `l2_has_wizard_money` is set, the locked exit to Ollivander's
  in `l2_diagon_alley_north` unlocks
- The Goblin Clerk's dialog changes to a dismissive one-liner

## Implementation notes

- This requires the branching dialog system in `dialog_box.gd` (options
  support already exists)
- Flag progression: `l2_goblin_challenged` → `l2_goblin_caught` →
  `l2_has_wizard_money`
- Consider storing the dialog tree in the NPC's export properties or in
  an external data structure

## Acceptance criteria

- [ ] Three-stage dialog works with correct branching
- [ ] Wrong answers loop back with hints
- [ ] `l2_has_wizard_money` flag set on completion
- [ ] Ollivander's exit unlocks after puzzle completion
- [ ] Goblin dialog changes after puzzle is solved
- [ ] Playtest: complete the full dialog tree and verify flag state
